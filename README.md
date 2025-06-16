### Exchange Google and Firebase OIDC tokens for AWS STS

*Credit: [Original Repo](https://github.com/salrashid123/awscompat)*

Simple [AWS Credential Provider](https://docs.aws.amazon.com/sdk-for-go/api/aws/credentials/) that uses [Google OIDC tokens](https://github.com/salrashid123/google_id_token).

Essentially, this will allow you to use a google `id_token` for AWS STS `session_token` and then access an aws resource that you've configured an Access Policy for the google identity.  This repo creates an `AWS Credential` derived from a `Google Credential` with the intent of using it for AWS's [IAM Role using External Identities](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html).


>> *NOTE*: the code in this repo is not supported by google.

### Implementations

* [golang](#golang)
* [java](#java)
* [python](#python)
* [dotnet](#dotnet)
* [nodejs](#nodejs)

### References

#### AWS
- [AWS Identity Providers and Federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers.html)
- [AWS WebIdentityRoleProvider](https://docs.aws.amazon.com/sdk-for-go/api/aws/credentials/stscreds/#WebIdentityRoleProvider)
- [AWS AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/sdk-for-go/api/service/sts/#STS.AssumeRoleWithWebIdentity)
- [aws.credential.Provider](https://godoc.org/github.com/aws/aws-sdk-go/aws/credentials#Provider)

#### Google
- [Authenticating using Google OpenID Connect Tokens](https://github.com/salrashid123/google_id_token)
- [Securely Access AWS Services from Google Kubernetes Engine (GKE)](https://blog.doit-intl.com/securely-access-aws-from-gke-dba1c6dbccba)
- [https://accounts.google.com/.well-known/openid-configuration](https://accounts.google.com/.well-known/openid-configuration)


### Google OIDC

AWS already supports Google OIDC endpoint out of the box as a provider so the setup is relatively simple: just define an AWS IAM policy that includes google and restrict it with a `Condition` that allows specific external identities as shown below:


- The following definition refers to Role: `arn:aws:iam::291738886548:role/s3webreaderrole`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "accounts.google.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "accounts.google.com:sub": "100147106996764479085"
        }
      }
    }
  ]
}
```

![images/s3_trust.png](images/s3_trust.png)


To do this by hand, first acquire an ID token (in this case through `gcloud` cli and service account):

```bash
$ gcloud auth activate-service-account --key-file=/path/to/gcp_service_account.json

$ export TOKEN=`gcloud auth print-identity-token --audiences=https://foo.bar`
```

Decode the token using the JWT decoder/debugger at [jwt.io](jwt.io)

The token will show the unique `sub` field that identifies the service account:

```json
{
  "aud": "https://foo.bar",
  "azp": "svc-2-429@mineral-minutia-820.iam.gserviceaccount.com",
  "email": "svc-2-429@mineral-minutia-820.iam.gserviceaccount.com",
  "email_verified": true,
  "exp": 1590898991,
  "iat": 1590895391,
  "iss": "https://accounts.google.com",
  "sub": "100147106996764479085"
}
```

Or using gcloud cli again:

```bash
$ gcloud iam service-accounts describe svc-2-429@mineral-minutia-820.iam.gserviceaccount.com
    displayName: Service Account A
    email: svc-2-429@mineral-minutia-820.iam.gserviceaccount.com
    etag: MDEwMjE5MjA=
    name: projects/mineral-minutia-820/serviceAccounts/svc-2-429@mineral-minutia-820.iam.gserviceaccount.com
    oauth2ClientId: '100147106996764479085'
    projectId: mineral-minutia-820
    uniqueId: '100147106996764479085'
```

Use this `uniqueId` value in the AWS IAM Role policy as shown above.

>> *Note*:  I tried to specify an audience value (`"accounts.google.com:aud": "https://someaud"`) within the AWS policy but that didn't seem to work)
Which means while the `audience` (aud) value is specified in some of the samples here (eg `"https://sts.amazonaws.com/` or `https://foo.bar`) can be anything since its not even currently used in the AWS condition policy)


Export the token and invoke the STS endpoint using the `RoleArn=` value defined earlier

```bash
export TOKEN=eyJhbGciOiJSUzI1...

$ curl -s "https://sts.amazonaws.com/?Action=AssumeRoleWithWebIdentity&DurationSeconds=3600&RoleSessionName=app1&RoleArn=arn:aws:iam::291738886548:role/s3webreaderrole&WebIdentityToken=$TOKEN&Version=2011-06-15&alt=json"
```

You should see AWS `Credential` object in the response
```xml
<AssumeRoleWithWebIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
  <AssumeRoleWithWebIdentityResult>
    <Audience>svc-2-429@mineral-minutia-820.iam.gserviceaccount.com</Audience>
    <AssumedRoleUser>
      <AssumedRoleId>AROAUH3H6EGKKRVTHVAVB:app1</AssumedRoleId>
      <Arn>arn:aws:sts::291738886548:assumed-role/s3webreaderrole/app1</Arn>
    </AssumedRoleUser>
    <Provider>accounts.google.com</Provider>
    <Credentials>
      <AccessKeyId>ASIAUH3H6EGKPI...</AccessKeyId>
      <SecretAccessKey>EM3Zu4RlDOKGkFPJpceemRqEzfazLk...</SecretAccessKey>
      <SessionToken>FwoGZXIvYXd...</SessionToken>
      <Expiration>2020-05-31T04:23:39Z</Expiration>
    </Credentials>
    <SubjectFromWebIdentityToken>100147106996764479085</SubjectFromWebIdentityToken>
  </AssumeRoleWithWebIdentityResult>
  <ResponseMetadata>
    <RequestId>38dd604d-6ce2-45b3-8e6f-1165ae0e24a1</RequestId>
  </ResponseMetadata>
</AssumeRoleWithWebIdentityResponse>
```

You can manually export the `Credential` in an cli (in this case, to access `s3`)

```bash
export AWS_ACCESS_KEY_ID=ASIAUH3H6EGKIL...
export AWS_SECRET_ACCESS_KEY=+nDF8O2yLDH13ug...
export AWS_SESSION_TOKEN=FwoGZXIvYXd...

$ aws s3 ls mineral-minutia --region us-east-2

    2020-05-29 23:04:07        213 main.py

```

To make this easier, the golang library contained in this repo wraps these steps and provides an AWS `Credential` object for you:


### Usage

There are several ways to exchange GCP credentials for AWS:

You can either delegate the task to get credentials to an external AWS `ProcessCredential` binary or perform the exchange in code as shown in this repo.

#### Process Credentials

In the `ProcessCredential` approach, AWS's client library and CLI will automatically invoke whatever binary is specified in aws's config file.  That binary will acquire a Google IDToken and then exchange it for a `WebIdentityToken` SessionToken from the AWS STS server.  Finally, the binary will emit the tokens to stdout in a specific format that AWS expects.  

For more information, see [Sourcing credentials with an external process](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sourcing-external.html) and [AWS Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

To use the process credential binary here, first

1. Build the binary (or download from "Releases" page)

```bash
go build  -o gcp-process-credentials main.go
```

2. Create AWS Config file

create a config file under `~/.aws/config` and specify the path to the binary, the ARN role and optionally the path to a specific gcp service account credential.
```bash
[default]
credential_process = /path/to/gcp-process-credentials  --aws-arn arn:aws:iam::291738886548:role/s3webreaderrole  --gcp-credential-file /path/to/svc.json  --region=us-east-2
```
In the snippet above, i've specified the GCP ServiceAccount Credentials file path.  If you omit that parameter, the binary will use [Google Application Default Credential](https://cloud.google.com/docs/authentication/production) to seek out the appropriate Google Credential Source.   

For example, if you run the binary on GCP VM, it will use the metadata server to get the id_token.   If you specify the ADC Environment varible `GOOGLE_APPLICATION_CREDENTIALS=/path/to.json`, the binary will use the service account specified there

3. Invoke AWS CLI or SDK library

Then either use the AWS CLI or any SDK client in any language.  The library will invoke the process credential for you and acquire the AWS token.

```bash
$ aws s3 ls mineral-minutia --region us-east-2
```

The example output from the binary is just JSON:

```bash

$ gcp-process-credentials  --aws-arn arn:aws:iam::291738886548:role/s3webreaderrole  --gcp-credential-file /path//to/svc.json  --region=us-east-2 | jq '.'
{
  "Version": 1,
  "AccessKeyId": "ASIAUH3H6EGKL7...",
  "SecretAccessKey": "YnjWyQFDeeqkRVJQit2uaj+...",
  "SessionToken": "FwoGZ...",
  "Expiration": "2020-06-05T19:24:57+0000"
}
```
