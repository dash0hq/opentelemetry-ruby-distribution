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
2. On a release branch, bump the version in
   [`lib/dash0/opentelemetry/version.rb`](lib/dash0/opentelemetry/version.rb).
   The version there is what gets published; the tag below must match it.
3. Merge the pending changelog fragments:

   ```sh
   bundle exec rake chloggen:update
   ```

   This folds every fragment under [`.chloggen/`](.chloggen) into
   [`CHANGELOG.md`](CHANGELOG.md)'s `Unreleased` section (grouped by change
   type) and deletes the fragments. Then rename `Unreleased` to the new
   version with today's date, and start a fresh `Unreleased` section.
4. Commit the change (e.g. `chore: release vX.Y.Z`), open a PR, and merge it to
   `main`. Merging does not publish anything — only pushing a tag does.
5. Tag the merged commit and push the tag:

   ```sh
   git checkout main && git pull
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

   The tag must point at the merged commit on `main`.
6. The `Release` workflow runs the full verification (`bundle exec rake`) and, if
   it passes, builds and publishes the gem to RubyGems via trusted publishing.

## After a release

Consuming the new version in the Dash0 operator is a one-line change in the
operator's Ruby build stage (install `dash0-opentelemetry` and point the injector
entry symlink at it) — tracked in the operator repository, not here.
