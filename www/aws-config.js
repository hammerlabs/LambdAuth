AWS.config.region = '<REGION>';
AWS.config.credentials = new AWS.CognitoIdentityCredentials({
  IdentityPoolId: '<IDENTITY_POOL_ID>'
});
var lambda = new AWS.Lambda();
