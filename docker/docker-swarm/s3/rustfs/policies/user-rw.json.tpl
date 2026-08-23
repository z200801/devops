{ "Version":"2012-10-17","Statement":[
  {"Effect":"Allow","Action":["s3:ListAllMyBuckets"],"Resource":["arn:aws:s3:::*"]},
  {"Effect":"Allow","Action":["s3:ListBucket","s3:GetBucketLocation"],"Resource":["arn:aws:s3:::__USER__-*"]},
  {"Effect":"Allow","Action":["s3:*"],"Resource":["arn:aws:s3:::__USER__-*","arn:aws:s3:::__USER__-*/*"]},
  {"Effect":"Allow","Action":["admin:CreateServiceAccount","admin:UpdateServiceAccount","admin:RemoveServiceAccount","admin:ListServiceAccounts"],"Resource":["arn:aws:s3:::*"]}]}
