# Releasing

Releases follow [Semantic Versioning](https://semver.org). Publishing happens in
CI via [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
(OIDC) when a version tag is pushed — no API keys are stored.

## One-time setup

On [rubygems.org](https://rubygems.org), configure a trusted publisher for the
`dash0-opentelemetry` gem pointing at this GitHub repository and the
`.github/workflows/release.yml` workflow.

On GitHub, configure the `rubygems` [deployment environment][gh-envs] with
required reviewers (a maintainer must approve each publish). The release
workflow uses this environment to gate RubyGems Trusted Publishing; without
required reviewers the environment is a no-op and any triggered run publishes
automatically. The workflow also refuses to publish a tag that is not reachable
from `origin/main`, so the two gates together mean a release requires (a) a
tag on a merged commit and (b) an explicit human approval on the environment.

[gh-envs]: https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#required-reviewers

## Cutting a release

1. Make sure `main` is green (`bundle exec rake`).
2. Bump the version in
   [`lib/dash0/opentelemetry/version.rb`](lib/dash0/opentelemetry/version.rb).
3. Merge the pending changelog fragments:

   ```sh
   bundle exec rake chloggen:update
   ```

   This folds every fragment under [`.chloggen/`](.chloggen) into
   [`CHANGELOG.md`](CHANGELOG.md)'s `Unreleased` section (grouped by change
   type) and deletes the fragments. Then rename `Unreleased` to the new
   version with today's date, and start a fresh `Unreleased` section.
4. Commit the change (e.g. `chore: release vX.Y.Z`).
5. Tag and push:

   ```sh
   git tag vX.Y.Z
   git push origin main --tags
   ```

6. The `Release` workflow runs the full verification (`bundle exec rake`), builds
   and publishes the gem to RubyGems via trusted publishing, and publishes a
   GitHub release for the tag with that version's `CHANGELOG.md` section as
   release notes and the built `.gem` attached as a release asset.

## After a release

The Dash0 operator's weekly `Check for Dash0 Ruby Distribution Updates`
workflow discovers the new version via `gh release list` against this
repository and opens a PR bumping the pinned version, so no manual step is
required there. That PR still updates the operator's Ruby build stage (install
`dash0-opentelemetry` and point the injector entry symlink at it) — tracked in
the operator repository, not here.
