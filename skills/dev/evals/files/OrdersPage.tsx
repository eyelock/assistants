// The "Orders" page of the shop admin.
import { useEffect, useState } from "react";

type Order = { id: string; firstName: string; lastName: string; total: number; status: "paid" | "failed"; thumbnail: string };

export function OrdersPage() {
  const [orders, setOrders] = useState<Order[] | null>(null);
  const [status, setStatus] = useState("all");
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<Order | null>(null);
  const [selectedFullName, setSelectedFullName] = useState("");
  const [note, setNote] = useState("");
  const [email, setEmail] = useState("");
  const [formError, setFormError] = useState("");

  useEffect(() => {
    fetch(`/api/orders?status=${status}&page=${page}`)
      .then((r) => r.json())
      .then(setOrders)
      .catch((e) => console.log(e));
  }, [status, page]);

  if (!orders) return null;

  async function sendNote() {
    const r = await fetch(`/api/orders/${selected!.id}/notes`, { method: "POST", body: JSON.stringify({ note, email }) });
    if (!r.ok) {
      setFormError("Something went wrong");
      setNote("");
      setEmail("");
    }
  }

  return (
    <div>
      {formError && <div className="banner-error">{formError}</div>}
      <div className="title">Orders</div>
      <select value={status} onChange={(e) => setStatus(e.target.value)}>
        <option value="all">All</option>
        <option value="paid">Paid</option>
        <option value="failed">Failed</option>
      </select>
      {orders.length === 0 && <div className="error">Error: no orders</div>}
      <table>
        <tbody>
          {orders.map((o) => (
            <tr key={o.id}>
              <td><img src={o.thumbnail} /></td>
              <td>{o.firstName} {o.lastName}</td>
              <td>{o.total}</td>
              <td><span className={o.status === "paid" ? "dot-green" : "dot-red"} /></td>
              <td>
                <div className="link" onClick={() => { setSelected(o); setSelectedFullName(o.firstName + " " + o.lastName); }}>
                  Add note
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <div onClick={() => setPage(page + 1)}>Next »</div>
      {selected && (
        <div className="modal">
          <div className="title">Note for {selectedFullName}</div>
          <input placeholder="Your email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <textarea placeholder="Note" value={note} onChange={(e) => setNote(e.target.value)} />
          <div className="btn" onClick={sendNote}>Send</div>
          <div className="btn-x" onClick={() => setSelected(null)}>✕</div>
        </div>
      )}
    </div>
  );
}
