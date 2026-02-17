```json task
{
  "mode": "lite",
  "slug": "agent-enhancement",
  "status": "done",
  "goal": "Adopt Build Any App prompt ideas to expand six agents with challenge assumptions, complexity assessment, Polish stage, and v2 suggestions",
  "non_goal": [
    "Do not add deploy agent in this task",
    "Do not add communication-style adaptation item #6"
  ],
  "gate": "standard",
  "created": "2026-02-15",
  "changes": [
    {
      "agent": "pm.md",
      "items": [
        "Principles +2: proactively challenge weak assumptions and suggest narrower starting scope"
      ]
    },
    {
      "agent": "architect.md",
      "items": [
        "Principles +2: challenge weak technical assumptions and state limitations honestly",
        "Phase Rules: add complexity assessment, external dependency list, and product outline"
      ]
    },
    {
      "agent": "qa.md",
      "items": [
        "Principles +1: challenge weak assumptions in scenario decomposition"
      ]
    },
    {
      "agent": "developer.md",
      "items": [
        "Phase Rules: output short summary after commit",
        "Critical Actions: when gate fails, show fix options for user selection"
      ]
    },
    {
      "agent": "designer.md",
      "items": [
        "Phase Rules +1: Polish stage (Full mode, between gate and Review)"
      ]
    },
    {
      "agent": "reviewer.md",
      "items": [
        "Output format adds Suggested Improvements section",
        "Output format adds optional Handoff Checklist"
      ]
    },
    {
      "file": "SKILL.md",
      "items": [
        "Gate failure flow adds option presentation",
        "Full mode adds Polish checkpoint",
        "Review output adds v2 suggestions"
      ]
    },
    {
      "file": "WORKFLOW.md",
      "items": [
        "Sync detailed documentation for all updates above"
      ]
    }
  ],
  "scenarios": [
    {
      "id": "S-agent-enhancement-01",
      "desc": "PM agent includes challenge assumptions and narrower-scope suggestion",
      "type": "unit"
    },
    {
      "id": "S-agent-enhancement-02",
      "desc": "Architect agent includes complexity, dependencies, product outline, and explicit limitations",
      "type": "unit"
    },
    {
      "id": "S-agent-enhancement-03",
      "desc": "QA agent includes challenge of scenario-splitting assumptions",
      "type": "unit"
    },
    {
      "id": "S-agent-enhancement-04",
      "desc": "Developer agent includes commit summary and gate-failure options",
      "type": "unit"
    },
    {
      "id": "S-agent-enhancement-05",
      "desc": "Designer agent includes Polish stage",
      "type": "unit"
    },
    {
      "id": "S-agent-enhancement-06",
      "desc": "Reviewer agent includes v2 suggestions and handoff",
      "type": "unit"
    },
    {
      "id": "S-agent-enhancement-07",
      "desc": "SKILL.md gate-failure flow includes option presentation",
      "type": "unit"
    },
    {
      "id": "S-agent-enhancement-08",
      "desc": "SKILL.md includes Polish checkpoint",
      "type": "unit"
    }
  ]
}
```
