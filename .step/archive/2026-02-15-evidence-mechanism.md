```json task
{
  "mode": "lite",
  "slug": "evidence-mechanism",
  "status": "done",
  "goal": "Complete evidence mechanism: gate requires slug, reviewer stores review evidence, and SKILL.md rules are updated",
  "non_goal": [
    "Do not change core gate.sh/scenario-check.sh logic (evidence write already exists)"
  ],
  "gate": "standard",
  "created": "2026-02-15",
  "scenarios": [
    {
      "id": "S-evidence-mechanism-01",
      "desc": "SKILL.md hard rule requires gate to specify task-slug",
      "type": "unit"
    },
    {
      "id": "S-evidence-mechanism-02",
      "desc": "SKILL.md mentions evidence persistence requirements",
      "type": "unit"
    },
    {
      "id": "S-evidence-mechanism-03",
      "desc": "reviewer.md includes review evidence persistence requirement",
      "type": "unit"
    },
    {
      "id": "S-evidence-mechanism-04",
      "desc": "WORKFLOW.md includes evidence types and lifecycle",
      "type": "unit"
    }
  ]
}
```
