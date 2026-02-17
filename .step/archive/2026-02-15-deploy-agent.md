```json task
{
  "mode": "lite",
  "slug": "deploy-agent",
  "status": "done",
  "goal": "Create step-deployer agent, optionally triggered after review pass, to provide deployment strategy guidance",
  "non_goal": [
    "Do not run deployment commands automatically",
    "Do not generate full CI/CD files (only guidance and template direction)",
    "Do not change existing Phase 0-5 flow (Deploy is optional extension)"
  ],
  "gate": "standard",
  "created": "2026-02-15",
  "scenarios": [
    {
      "id": "S-deploy-agent-01",
      "desc": "deployer.md exists and has valid frontmatter",
      "type": "unit"
    },
    {
      "id": "S-deploy-agent-02",
      "desc": "routing includes deploy entry",
      "type": "unit"
    },
    {
      "id": "S-deploy-agent-03",
      "desc": "SKILL.md routing and role table include deploy",
      "type": "unit"
    },
    {
      "id": "S-deploy-agent-04",
      "desc": "WORKFLOW.md includes Deploy section",
      "type": "unit"
    }
  ]
}
```
