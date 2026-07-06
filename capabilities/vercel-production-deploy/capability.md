# vercel prod deploy

## Job

Deploy the `main` branch to Vercel Production using the project's production configuration.

## Implementation

Run the `vercel-production-deploy` implementation.

`VERCEL_ACCESS_TOKEN` comes from `.kody/secrets.enc`. Non-secret deploy config comes from `.kody/variables.json`.

## Allowed Commands

- Run the `vercel-production-deploy` implementation.

## Restrictions

- Manual only.
- Deploys the configured production branch, default `main`.
