# Salesforce DX Project

Salesforce DX is a development approach that brings source-driven development, team collaboration, and continuous integration to the Salesforce Platform. Instead of working directly in an org through a web browser, you work with metadata as source files in a local DX project, track changes in version control, and deploy through automated processes.

This project template gets you started with the tools and structure you need to build Salesforce applications using source control, scratch orgs, and the Salesforce CLI.

## Prerequisites

Before you start, make sure you have:

- **Salesforce CLI** - Download from [developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli). See [Install Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm) for details.
- **VS Code with Salesforce Extension Pack** - See [Installation Instructions](https://developer.salesforce.com/docs/platform/sfvscode-extensions/guide/install.html) for details. Includes the Agentforce Vibes extension.
- **A development org** - Sign up for a free Developer Edition org [here](https://developer.salesforce.com/signup).
- **Dev Hub enabled** (optional, required to create scratch orgs) - You can enable Dev Hub in your development org under Setup > Dev Hub.  See [Provide Developers Access to Salesforce DX Tools](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_setup_dx_tools.htm).

## Project Structure

Your DX project follows this structure:

- **`force-app/main/default/`** - Your metadata source files live in this default package directory. You can configure additional package directories in the `sfdx-project.json` file.
- **`config/`** - Scratch org definitions and project settings
- **`scripts/`** - Automation scripts for common tasks
- **`sfdx-project.json`** - Project manifest that defines package directories, namespace, API version, and other project-level settings

See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm).

## GitHub Actions Deployments

The GitHub Actions workflow validates feature branches (`feature/*`, `bugfix/*`) and pull requests targeting `dev`, `qa`, `uat`, or `main`. Validation installs the committed lockfile with `npm ci`, then runs LWC unit tests and ESLint. Pull request validation does not receive Salesforce credentials.

Feature branches start from `dev` and are merged to `dev` by pull request. A successful deployment after a push to a persistent branch opens or reuses the next promotion PR:

1. A merge to `dev` deploys to the Dev sandbox, then opens `dev` → `qa`.
2. A merge to `qa` deploys to the QA sandbox, then opens `qa` → `uat`.
3. A merge to `uat` waits for approval from the QA reviewers configured on the `uat` GitHub Environment, then deploys to the UAT sandbox. After success, the workflow opens `uat` → `main`.
4. A merge to `main` waits for the required reviewers configured on the `production` GitHub Environment, then deploys to Production.

Feature pushes do not automatically merge into QA, UAT, or Production. Promotion PRs are created only after the prior stage deploy succeeds. Reviewers must inspect and merge each PR to move the code forward.

### GitHub setup

1. Create GitHub Environments named `dev`, `qa`, `uat`, and `production`. Restrict each environment to its matching branch: `dev`, `qa`, `uat`, or `main` for `production`.
2. Configure required reviewers on `uat` (QA sign-off before the UAT deployment) and `production` (stakeholder approval before Production). GitHub Environment approvals pause the deployment job until approval. Use distinct reviewer teams where appropriate.
3. Add these environment secrets separately to each environment so each stage authenticates to its own Salesforce org:
	- `SF_CLIENT_ID`: the Salesforce Connected App consumer key.
	- `SF_USERNAME`: the deployment integration user's username for that org.
	- `SF_JWT_KEY`: the PEM private key corresponding to the certificate configured in the Connected App.
	- `SF_LOGIN_URL`: the org login URL, such as `https://test.salesforce.com` for sandboxes or `https://login.salesforce.com` for Production. Prefer the org's My Domain URL when required by your Salesforce configuration.
4. Create a GitHub App installed on this repository with repository `Contents: Read-only` and `Pull requests: Read and write` permissions. Add repository Actions secrets `PROMOTION_APP_ID` and `PROMOTION_APP_PRIVATE_KEY`; the app token is used only to open/reuse promotion PRs. This avoids the workflow-trigger suppression that applies to PRs created with the default `GITHUB_TOKEN`.
5. Configure Salesforce JWT bearer authentication for a Connected App in each org and authorize the matching integration user. Grant only the metadata deployment and test-running permissions needed for this project.
6. Protect `dev`, `qa`, `uat`, and `main` with pull-request requirements. Require the `Validate Salesforce source` status check, at least one approval, dismissal of stale approvals, and restrictions on bypasses and force-pushes. Configure `CODEOWNERS` or restricted reviewer teams if stage-specific review ownership is needed. Do not allow direct pushes to persistent branches.

#### Salesforce Connected App and JWT setup

1. In each Salesforce org, create or configure a Connected App with OAuth enabled and digital signatures enabled. Upload the public certificate, enable the JWT bearer flow, and note the consumer key as `SF_CLIENT_ID`.
2. Create a dedicated deployment integration user in each org. Grant the minimum required deployment and Apex test permissions, authorize that user for the Connected App, and use its username as `SF_USERNAME`.
3. Generate a private key and matching public certificate using your organization's approved key-management process. For example, with OpenSSL on a secured workstation:

	```sh
	openssl genrsa -out server.key 2048
	openssl req -new -x509 -key server.key -out server.crt -days 3650
	```

	Upload only `server.crt` to Salesforce. Store the contents of `server.key` as the environment secret `SF_JWT_KEY`; never commit the private key or print it in workflow logs.
4. Set each environment's `SF_LOGIN_URL` to the appropriate Salesforce My Domain or login URL. Use a sandbox login URL for Dev/QA/UAT and the production login URL for Production.
5. Rotate the certificate/private key on a schedule and immediately after any suspected exposure. Update the Salesforce certificate and GitHub Environment secret together.

#### Branch protection and promotion

1. In **Settings → Branches**, create a ruleset (or branch rules) for each of `dev`, `qa`, `uat`, and `main`. Require PRs, at least one approval, dismissal of stale approvals, and the `Validate Salesforce source` status check. Block force-pushes and branch deletion, and restrict bypasses to the smallest release-admin group.
2. Developers create `feature/*` or `bugfix/*` branches from `dev`, then open PRs into `dev`.
3. After each promotion PR is opened, review its changes and merge it only after the required checks and sign-offs. A successful deployment is required before the next promotion PR is created.
4. In **Settings → Environments**, add `dev`, `qa`, `uat`, and `production`. For each, allow deployments only from its matching persistent branch. Set the `uat` Environment reviewer team to the QA sign-off group and `production` reviewers to the final stakeholder/release approvers.
5. Re-run a failed deployment only after reviewing the failure and confirming the target org is in a safe state. Salesforce deployments are not automatically rolled back by GitHub Actions.

#### Test levels and destructive changes

The workflow uses `RunLocalTests` for every environment, including Production, so deployment runs the org's local Apex tests. This is the recommended default when the org's tests are reliable. `RunSpecifiedTests` can reduce deployment time, but use it only when the named tests cover the deployed components and satisfy Salesforce's per-component coverage requirements; an incomplete test list can cause deployment failure or weaker validation. Keep the selected test policy consistent across stages and validate Production-bound changes with the same policy before approval.

Destructive changes are not enabled by default. For removals, include reviewed `destructiveChangesPre.xml` or `destructiveChangesPost.xml` manifests with an API-versioned `package.xml`, then update the deploy command to pass `--pre-destructive-changes` or `--post-destructive-changes` explicitly. Test destructive deployments in a sandbox first, include them in the promotion PR, and keep the UAT and Production environment approval gates. Do not use `--ignore-warnings` or broad wildcard deletion manifests as a substitute for review.


## Get Started

Ready to start developing? The [Get Started with Salesforce DX](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_get_started_dx.htm) guide walks you through your first project, from creating a scratch org to creating a simple Apex class or LWC to deploying your code to a sandbox.

## Common Salesforce CLI Commands

Here are common CLI commands that you'll use the most:

- `sf org login web`: Authorize an org
- `sf org open`: Open your org in a browser
- `sf org create scratch`: Create a scratch org
- `sf project deploy start`: Deploy metadata to your org
- `sf project retrieve start`: Retrieve metadata from your org
- `sf template generate <artifact>`: Scaffold new components, such as Apex classes and triggers, LWC components, Lightning apps, and more
- `sf apex <command>`: Run Apex tests, run anonymous Apex blocks, and view logs
- `sf data <command>`: Work with test data
- `sf alias <command>`: Manage org aliases
- `sf config <command>`: Configure CLI settings

## Use Agentforce Vibes to Build Lightning Apps

Transform your ideas into custom Lightning apps that extend CRM workflows directly in Lightning Experience. Through natural conversations with Agentforce Vibes, implement custom objects and fields, complex business logic, and dynamic UI components. See [Build a Lightning App Using Agentforce Vibes](https://developer.salesforce.com/docs/platform/einstein-for-devs/guide/lexapp-overview.html).

## Additional Resources

- [Agentforce Vibes Developer Guide](https://developer.salesforce.com/docs/platform/einstein-for-devs/guide/einstein-overview.html)
- [Salesforce CLI Installation Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Salesforce CLI Plugin Development Guide](https://developer.salesforce.com/docs/platform/salesforce-cli-plugin/guide/conceptual-overview.html)
- [Salesforce VS Code Extensions Documentation](https://developer.salesforce.com/tools/vscode/)

