---
name: java-lang
description: Java development workflow — build tooling, testing, code style, and common patterns.
---

# Java Development

You assist with Java development following modern Java conventions and standard build tooling.

## Build

### Maven

```bash
mvn clean compile
```

### Gradle

```bash
./gradlew build
```

- Always use the Gradle wrapper (`./gradlew`) — never a system-installed Gradle
- Use `--console=plain` in CI for clean log output
- Build all modules before moving on. Fix compilation errors first.

## Test

```bash
# Maven
mvn test

# Gradle
./gradlew test
```

- Use JUnit 5 (`org.junit.jupiter`) — not JUnit 4
- Use `@DisplayName` for readable test names
- Use `@Nested` classes to group related tests
- Use `@ParameterizedTest` with `@CsvSource`, `@MethodSource`, or `@EnumSource` for table-driven tests
- Use AssertJ for fluent assertions: `assertThat(result).isEqualTo(expected)`

### Test patterns

```java
@Nested
@DisplayName("UserService.create")
class Create {

    @Test
    @DisplayName("creates user with valid input")
    void createsUserWithValidInput() {
        var input = new CreateUserRequest("alice", "alice@example.com");
        var result = service.create(input);
        assertThat(result.name()).isEqualTo("alice");
    }

    @Test
    @DisplayName("rejects duplicate email")
    void rejectsDuplicateEmail() {
        service.create(new CreateUserRequest("alice", "alice@example.com"));
        assertThatThrownBy(() -> service.create(new CreateUserRequest("bob", "alice@example.com")))
            .isInstanceOf(DuplicateEmailException.class);
    }
}
```

- Use `@TempDir` for filesystem isolation
- Use Mockito sparingly — prefer real implementations and in-memory fakes over mocks
- Integration tests in a separate source set (`src/integrationTest/java`)

## Format and Lint

### Formatting

Use a consistent formatter configured once for the project:

- **google-java-format**: `mvn com.spotify.fmt:fmt-maven-plugin:format`
- **Spotless** (Gradle): `./gradlew spotlessApply`
- **IntelliJ**: Use `.editorconfig` and shared code style XML

### Static analysis

- **SpotBugs**: Find common bug patterns
- **Error Prone**: Compile-time error checking (recommended as a compiler plugin)
- **Checkstyle**: Code style enforcement

Fix issues directly rather than suppressing warnings unless there's a genuine false positive.

## Dependency management

### Maven

```xml
<dependencyManagement>
    <dependencies>
        <!-- Pin versions here -->
    </dependencies>
</dependencyManagement>
```

### Gradle

```kotlin
dependencies {
    implementation(platform("org.springframework.boot:spring-boot-dependencies:3.x.x"))
}
```

- Use BOMs (Bill of Materials) to manage transitive dependency versions
- Keep dependencies up to date — use Dependabot or Renovate
- Check licenses before adding new dependencies
- Prefer well-maintained, widely-used libraries over niche ones

## Project structure

```
project/
├── src/
│   ├── main/java/com/example/project/
│   │   ├── domain/           # Domain objects, business rules
│   │   ├── service/          # Business logic, orchestration
│   │   ├── repository/       # Data access
│   │   ├── controller/       # API endpoints
│   │   └── config/           # Configuration classes
│   ├── main/resources/
│   │   └── application.yml
│   └── test/java/com/example/project/
│       └── (mirrors main structure)
├── pom.xml / build.gradle.kts
└── .editorconfig
```

- Package by feature, not by layer, for larger projects: `com.example.project.order` contains the controller, service, repository, and domain objects for orders
- Keep the package hierarchy flat — avoid deep nesting

## Code patterns

### Records and sealed types (Java 17+)

Use records for immutable data carriers:

```java
public record CreateUserRequest(String name, String email) {}
```

Use sealed interfaces for closed type hierarchies:

```java
public sealed interface Result<T> {
    record Success<T>(T value) implements Result<T> {}
    record Failure<T>(String error) implements Result<T> {}
}
```

### Optional

- Return `Optional<T>` from methods that may not have a result — never return null
- Don't use `Optional` as a method parameter or field — it's for return types
- Use `orElseThrow()` with a descriptive exception, not `get()`

### Error handling

- Use specific exception types, not generic `RuntimeException`
- Wrap and rethrow with context: `throw new OrderCreationException("Failed to create order for user " + userId, cause)`
- Don't catch `Exception` broadly — catch specific types
- Use try-with-resources for all `AutoCloseable` resources
- Never swallow exceptions with an empty catch block

### Null safety

- Annotate parameters and return types with `@Nullable` / `@NonNull` (JetBrains or Jakarta annotations)
- Fail fast on unexpected nulls at public API boundaries: `Objects.requireNonNull(param, "param must not be null")`
- Prefer empty collections over null: return `List.of()` not `null`

### Modern Java

- Use `var` for local variables where the type is obvious from context
- Use text blocks (`"""`) for multi-line strings
- Use `switch` expressions with pattern matching (Java 21+)
- Use virtual threads (Java 21+) for I/O-bound concurrent work instead of thread pool tuning
- Use `Stream` API for collection transformations, but keep pipelines short and readable

## CI pipeline

Standard CI jobs:

1. **Build** — `mvn compile` / `./gradlew compileJava`
2. **Test** — `mvn test` / `./gradlew test`
3. **Lint** — SpotBugs, Error Prone, Checkstyle
4. **Format Check** — Spotless or google-java-format in check mode
5. **All Clear** — aggregator job for branch protection

Use the project's Java version via a `.java-version` file or `toolchains` configuration.
