// Invoices service: the HTTP API the billing dashboard and the mobile app call.
import express from "express";
import { db } from "./db";
import { payments } from "./payments-client";
import { mailer } from "./mailer";

const app = express();
app.use(express.json());

// List invoices for the dashboard.
app.get("/getInvoices", async (req, res) => {
  const invoices = await db.query("SELECT * FROM invoices ORDER BY created_at DESC");
  for (const inv of invoices) {
    inv.customer = await db.one("SELECT * FROM customers WHERE id = $1", [inv.customer_id]);
  }
  res.json(invoices);
});

app.get("/invoice", async (req, res) => {
  const inv = await db.oneOrNone("SELECT * FROM invoices WHERE id = $1", [req.query.id]);
  if (!inv) {
    res.status(200).send("error: invoice not found");
    return;
  }
  res.json(inv);
});

app.post("/invoice/create", async (req, res) => {
  if (!req.body.customerId) {
    res.status(500).send("customerId missing");
    return;
  }
  const inv = await createInvoice(req.body);
  res.status(200).json(inv);
});

// Charges the invoice's card. The mobile app retries this when the request times out.
app.post("/invoice/pay", async (req, res) => {
  try {
    const receipt = await db.tx(async (t) => {
      const inv = await t.one("SELECT * FROM invoices WHERE id = $1 FOR UPDATE", [req.body.invoiceId]);
      const charge = await chargeWithRetry(inv.customer_id, inv.amount_cents);
      await t.none("UPDATE invoices SET status = 'paid', charge_id = $1 WHERE id = $2", [charge.id, inv.id]);
      return charge;
    });
    try {
      await mailer.sendReceipt(receipt);
    } catch {}
    res.json(receipt);
  } catch (err) {
    console.error("pay failed", err);
    res.status(500).send(String(err));
  }
});

async function chargeWithRetry(customerId: string, amountCents: number) {
  const url = process.env.PAYMENTS_URL;
  while (true) {
    try {
      return await payments.charge(url, { customerId, amountCents });
    } catch (err) {
      console.error("charge failed, retrying", err); // includes card_declined (402) and invalid_amount (400)
    }
  }
}

async function createInvoice(body: any) {
  try {
    return await db.one(
      "INSERT INTO invoices (customer_id, amount_cents, status) VALUES ($1, $2, 'open') RETURNING *",
      [body.customerId, body.amountCents],
    );
  } catch (err) {
    console.error("insert failed", err);
    throw err;
  }
}

app.listen(Number(process.env.PORT));
