AWSTemplateFormatVersion: '2010-09-09'
Description: ITC5205 Assignment 2 - YOLOv5 image object identification system using S3, Lambda, REST API Gateway and API-key security

Parameters:
  BucketName:
    Type: String
    Default: itc5205-yolov5-demo-20036047
    Description: Globally unique S3 bucket name for input images and detection results.
  LambdaImageUri:
    Type: String
    Description: ECR image URI for the Lambda container image that contains YOLOv5, PyTorch and project source code.
  ApiStageName:
    Type: String
    Default: prod
  ApiKeyValue:
    Type: String
    NoEcho: true
    MinLength: 20
    Description: API key value used to protect the /detect endpoint. The deploy script generates this automatically when it is not supplied.
  OutputPrefix:
    Type: String
    Default: results/
  DefaultConfidence:
    Type: String
    Default: '0.25'

Resources:
  ImageBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: Enabled

  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub itc5205-yolov5-lambda-role-${AWS::StackName}
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: S3ReadWriteAndCloudWatchLogs
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Sid: S3InputOutputAccess
                Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                Resource: !Sub arn:aws:s3:::${BucketName}/*
              - Sid: S3ListForTestingOnly
                Effect: Allow
                Action:
                  - s3:ListBucket
                Resource: !Sub arn:aws:s3:::${BucketName}
              - Sid: CloudWatchLogging
                Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: '*'

  DetectionFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub itc5205-yolov5-detect-${AWS::StackName}
      Role: !GetAtt LambdaExecutionRole.Arn
      PackageType: Image
      Code:
        ImageUri: !Ref LambdaImageUri
      MemorySize: 4096
      Timeout: 120
      Environment:
        Variables:
          MODEL_NAME: yolov5s
          OUTPUT_PREFIX: !Ref OutputPrefix
          DEFAULT_CONFIDENCE: !Ref DefaultConfidence

  DetectRestApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub itc5205-yolov5-api-${AWS::StackName}
      Description: API Gateway REST API for protected YOLOv5 object detection requests.
      EndpointConfiguration:
        Types:
          - REGIONAL

  DetectResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref DetectRestApi
      ParentId: !GetAtt DetectRestApi.RootResourceId
      PathPart: detect

  DetectPostMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref DetectRestApi
      ResourceId: !Ref DetectResource
      HttpMethod: POST
      AuthorizationType: NONE
      ApiKeyRequired: true
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${DetectionFunction.Arn}/invocations
      MethodResponses:
        - StatusCode: 200

  DetectOptionsMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref DetectRestApi
      ResourceId: !Ref DetectResource
      HttpMethod: OPTIONS
      AuthorizationType: NONE
      ApiKeyRequired: false
      Integration:
        Type: MOCK
        RequestTemplates:
          application/json: '{"statusCode": 200}'
        IntegrationResponses:
          - StatusCode: 200
            ResponseParameters:
              method.response.header.Access-Control-Allow-Headers: "'content-type,x-api-key'"
              method.response.header.Access-Control-Allow-Methods: "'POST,OPTIONS'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
      MethodResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Access-Control-Allow-Headers: true
            method.response.header.Access-Control-Allow-Methods: true
            method.response.header.Access-Control-Allow-Origin: true

  ApiInvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref DetectionFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${DetectRestApi}/*/POST/detect

  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn:
      - DetectPostMethod
      - DetectOptionsMethod
    Properties:
      RestApiId: !Ref DetectRestApi
      Description: Deployment for the protected /detect endpoint.

  ApiStage:
    Type: AWS::ApiGateway::Stage
    Properties:
      RestApiId: !Ref DetectRestApi
      DeploymentId: !Ref ApiDeployment
      StageName: !Ref ApiStageName
      MethodSettings:
        - ResourcePath: '/*'
          HttpMethod: '*'
          LoggingLevel: INFO
          MetricsEnabled: true

  DetectionApiKey:
    Type: AWS::ApiGateway::ApiKey
    DependsOn: ApiStage
    Properties:
      Name: !Sub itc5205-yolov5-api-key-${AWS::StackName}
      Description: API key required for POST /detect requests.
      Enabled: true
      Value: !Ref ApiKeyValue
      StageKeys:
        - RestApiId: !Ref DetectRestApi
          StageName: !Ref ApiStage

  DetectionUsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    DependsOn: ApiStage
    Properties:
      UsagePlanName: !Sub itc5205-yolov5-usage-plan-${AWS::StackName}
      Description: Basic throttling plan for assignment testing.
      ApiStages:
        - ApiId: !Ref DetectRestApi
          Stage: !Ref ApiStage
      Throttle:
        RateLimit: 5
        BurstLimit: 10
      Quota:
        Limit: 500
        Period: MONTH

  DetectionUsagePlanKey:
    Type: AWS::ApiGateway::UsagePlanKey
    Properties:
      KeyId: !Ref DetectionApiKey
      KeyType: API_KEY
      UsagePlanId: !Ref DetectionUsagePlan

Outputs:
  BucketName:
    Description: S3 bucket used for uploads and results.
    Value: !Ref ImageBucket
  LambdaFunctionName:
    Description: Lambda function created by the stack.
    Value: !Ref DetectionFunction
  DetectApiUrl:
    Description: Live API Gateway URL to paste into the report after deployment.
    Value: !Sub https://${DetectRestApi}.execute-api.${AWS::Region}.amazonaws.com/${ApiStageName}/detect
  ApiKeyName:
    Description: API key name. The key value is printed by the deploy script and should be kept private.
    Value: !Ref DetectionApiKey
