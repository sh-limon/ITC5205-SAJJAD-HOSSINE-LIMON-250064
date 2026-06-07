# AWS Evidence Capture Guide

Capture these real screenshots after deployment and replace the prototype images in the report.

1. S3 bucket screenshot showing `uploads/` and `results/` prefixes.
2. Lambda function screenshot showing container image, memory 4096 MB, timeout 120 seconds and environment variables.
3. API Gateway REST API screenshot showing `/detect` POST with **API Key Required = true**.
4. API Gateway usage plan/API key screenshot showing the usage plan linked to the stage.
5. CloudWatch log screenshot for the first invocation showing model loading messages.
6. CloudWatch log screenshot for a warm invocation showing faster duration or no repeated model load.
7. S3 results screenshot showing annotated image and JSON output under `results/`.

Do not mark prototype images as final evidence. Use screenshots from the actual AWS account used for the submission.
