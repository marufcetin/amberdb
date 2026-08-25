# Contributing to AmberDB

Thank you for your interest in contributing to **AmberDB**! We appreciate bug reports, documentation improvements, feature suggestions, and code contributions.

---

## Code of Conduct

Please be polite, respectful, and collaborative in all interactions within this project.

---

## How to Report Bugs

When filing a bug report:
1. Search existing [GitHub Issues](https://github.com/marufcetin/amberdb/issues) to ensure the issue hasn't been reported.
2. Provide a minimal, reproducible Perl test case or script demonstrating the bug.
3. Include your environment details:
   - Operating System (Linux, macOS, Windows/Strawberry Perl)
   - Perl version (`perl -v`)
   - Berkeley DB / `DB_File` version
   - AmberDB version

---

## How to Propose Features

1. Open an issue on GitHub describing the feature, rationale, and sample API syntax.
2. Discuss the design and compatibility implications before submitting large PRs.

---

## Development & Testing Workflow

### 1. Clone Repository & Install Dependencies

```bash
git clone https://github.com/marufcetin/amberdb.git
cd amberdb
cpanm --installdeps .
```

### 2. Run Test Suite

Run the full test suite using `prove`:

```bash
prove -l t/
```

Or via MakeMaker:

```bash
perl Makefile.PL
make
make test
```

### 3. Coding Guidelines

- **Perl Version**: Maintain compatibility with **Perl 5.16+**.
- **Indentation & Style**: 4 spaces per indentation level. Avoid hard tabs in code.
- **Documentation**: If adding or changing methods, update POD documentation in the respective module and in `README.md` or `docs/`.
- **Tests**: Add corresponding unit tests in `t/` for any bug fix or new feature. Always use `File::Temp::tempdir(CLEANUP => 1)` for temporary test databases.

---

## Submitting Pull Requests

1. Fork the repository on GitHub.
2. Create a topic branch: `git checkout -b feature/my-new-feature`.
3. Commit your changes with clear, descriptive commit messages.
4. Ensure all tests pass: `prove -l t/`.
5. Push to your branch and open a Pull Request against the `main` branch.
