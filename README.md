# UiPath CLI CI/CD demo

A small, working pipeline that builds a UiPath solution once and promotes the same package across three tenants with GitHub Actions and the `uip` CLI. No Automation Ops Pipelines, no user token in CI: every stage logs in as an external app.

| Tenant | GitHub environment | External app | Gate |
| --- | --- | --- | --- |
| `CicdDev` | `dev` | `cicd-dev` | none, deploys on merge |
| `CicdTest` | `test` | `cicd-test` | merge of a promotion PR |
| `CicdProd` | `prod` | `cicd-prod` | promotion PR + CODEOWNERS review + environment approval |

## The flow

1. **Validate** (`validate.yml`, every PR): smoke-test the agent rules, `uip solution pack --dry-run`, and check that any changed environment file names a version that was actually built.
2. **Build** (`build.yml`, merge to `main` touching `solutions/`): pack as `1.0.<run>`, store the zip as a GitHub release, deploy to DEV, record it in `environments/dev.yaml`, open the PR "Promote … to TEST".
3. **Promote** (`promote.yml`, merge touching `environments/test.yaml` or `prod.yaml`): publish the stored zip to that tenant and `deploy upgrade` in place. After TEST it opens the PROD PR. PROD waits for an approver.

`environments/*.yaml` is the record of what runs where. Open PRs labelled `promote:*` are the queue of pending moves; merged PRs are the audit trail; rollback is a revert PR.

## What's in the repo

```
solutions/CicdDemo/            the solution (.uipx + generated resources), committed
  OrderTriage/                 a deterministic LangGraph coded agent (no LLM call)
environments/{dev,test,prod}.yaml
scripts/deploy.sh              publish + deploy run (first time) or deploy upgrade (every later version)
scripts/open-promotion-pr.sh   writes the version line and opens the PR
scripts/bootstrap-credentials.sh  one-time: create the external apps, store them as environment secrets
.github/workflows/             validate, build, promote, deploy (reusable)
```

## Try it

Change `RULES_VERSION` in `solutions/CicdDemo/OrderTriage/main.py`, open a PR, merge it, then follow the promotion PRs the pipeline opens.

## One-time setup

- External apps and secrets: `scripts/bootstrap-credentials.sh <owner/repo>` (org admin, user login).
- Each app needs, in its own tenant: the **Solutions Contributor** tenant role and a folder role on `Shared`.
- Repository variables: `UIP_ORG`, `UIP_AUTHORITY`, `UIP_SCOPES`. Environment variable: `UIP_TENANT`.
- Settings → Actions → General: allow GitHub Actions to create pull requests.
- Pin `uip` (1.204.0+). App-only `deploy list` / `deploy upgrade` need it.
