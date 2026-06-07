# Cold-Start Evidence Table

Fill this table after triggering the API multiple times. Use CloudWatch Logs for the values.

| Test run | Time | Evidence from CloudWatch | Init/model-load observed? | Duration / billed duration | Explanation |
| --- | --- | --- | --- | --- | --- |
| Run 1 after idle period | [insert time] | model_load_start and model_load_complete visible | Yes | [insert ms] | Cold start because Lambda container loaded dependencies/model |
| Run 2 immediately after run 1 | [insert time] | No repeated model_load_start message | No | [insert ms] | Warm start because global model was reused |
| Run 3 after short wait | [insert time] | [insert log evidence] | [Yes/No] | [insert ms] | [explain behaviour] |

Suggested report wording after filling real values:
The first invocation showed a cold start because CloudWatch Logs recorded model_load_start and model_load_complete before detection. The next invocation reused the global model and did not repeat the model-loading messages, so its duration was lower. This confirms cold-start behaviour using CloudWatch evidence rather than theory.
