# Releasing

Releases follow [Semantic Versioning](https://semver.org). Publishing happens in
CI via [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
(OIDC) when a version tag is pushed — no API keys are stored.

## One-time setup

On [rubygems.org](https://rubygems.org), configure a trusted publisher for the
`dash0-opentelemetry` gem pointing at this GitHub repository and the
`.github/workflows/release.yml` workflow.

## Cutting a release

1. Make sure `main` is green (`bundle exec rake`).
2. Bump the version in
   [`lib/dash0/opentelemetry/version.rb`](lib/dash0/opentelemetry/version.rb).
3. Update [`CHANGELOG.md`](CHANGELOG.md): rename the `Unreleased` section to the
   new version with today's date, and start a fresh `Unreleased` section.
4. Commit the change (e.g. `chore: release vX.Y.Z`).
5. Tag and push:

   ```sh
   git tag vX.Y.Z
   git push origin main --tags
   ```

6. The `Release` workflow runs the full verification (`bundle exec rake`) and, if
   it passes, builds and publishes the gem to RubyGems via trusted publishing.

## After a release

Consuming the new version in the Dash0 operator is a one-line change in the
operator's Ruby build stage (install `dash0-opentelemetry` and point the injector
entry symlink at it) — tracked in the operator repository, not here.
