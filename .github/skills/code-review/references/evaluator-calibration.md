# Evaluator Calibration

- The evaluator should be tuned for skepticism, not balanced feedback. A lenient
  evaluator provides no value over self-review. If findings feel too soft, add
  the calibration step from Section B Step 3.
- For subjective acceptance criteria (design quality, UX feel, originality),
  provide few-shot examples of what PASS looks like before running the evaluator.
  Subjective criteria without examples produce inconsistent verdicts.
- The separate-session pattern is the most important change from a basic review.
  Even if you do nothing else in this skill, running review in a fresh session
  catches significantly more issues than same-session self-review.
- After evaluator findings are resolved, a final `release-readiness` pass
  confirms the spec is linked, tests are green, and lessons are written back
  before the MR is opened.
