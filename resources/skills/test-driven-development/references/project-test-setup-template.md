# Project Test Setup Template

Add project-specific test setup in a `## Project Test Setup` section below.
Include: how to run tests, how to run a single test file, how to run with
coverage, any test database setup commands, and any common mock patterns
your project uses.

---

## Project Test Setup
# Fill this in for your project:

```bash
# Run all tests
[your command here, e.g.: npm test / pytest / ./gradlew test]

# Run a single test file
[e.g.: npm test -- tests/unit/export.service.test.ts]
[e.g.: pytest tests/unit/test_export_service.py]

# Run with coverage
[e.g.: npm test -- --coverage]
[e.g.: pytest --cov=src tests/]

# Run integration tests only
[e.g.: npm run test:integration]
[e.g.: pytest tests/integration/]
```
