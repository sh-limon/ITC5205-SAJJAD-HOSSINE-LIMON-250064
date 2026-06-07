FROM public.ecr.aws/lambda/python:3.10

WORKDIR ${LAMBDA_TASK_ROOT}
COPY code/requirements.txt ./requirements.txt
RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir -r requirements.txt
COPY code/lambda_function.py ./lambda_function.py
CMD ["lambda_function.lambda_handler"]
