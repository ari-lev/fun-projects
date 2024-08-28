// Written by Ari Lev
// Based on the It's-Log project by Brad Chapman
// https://github.com/bradtchapman/psumac2023

var snsTopicARN = "arn:aws:sns:us-east-1:XXXX:SysDiag";
var util = require('util');
var AWS = require('aws-sdk');
var s3 = new AWS.S3();

exports.handler = function(event, context, callback) {
    
// Use the event passed from S3 to Lambda to retrieve the parameters necessary to run this function.
var s3Event = event.Records[0];
var srcBucket = s3Event.s3.bucket.name;
var srcRegion = s3Event.s3.bucket.awsRegion;
var srcEvent = s3Event.eventName;
var srcTime = s3Event.eventTime;
var srcKey = s3Event.s3.object.key;
var signedUrlValidSeconds = 86400*7;
var signedUrlValidDays = Math.round(signedUrlValidSeconds / 86400);

// Generate Signed URL:
var signedUrl = s3.getSignedUrl('getObject', {
Bucket: srcBucket,
Key: srcKey,
Expires: signedUrlValidSeconds
    })

// Extract and format the user name from the filename
    const user = srcKey.includes('_')
    ? srcKey.split('_')[1].replace(/-/g, ' ').replace(/\b\w/g, char => char.toUpperCase())
    : srcKey.replace(/-/g, ' ').replace(/\b\w/g, char => char.toUpperCase());

// Construct the message being sent via SNS.
var msg =   "A new macOS System Diagnostic file has been uploaded to AWS.\n\n" +
            "Reporter: " + user + "\n" +
            "File Name: " + srcKey + "\n\n" +
            "Download the file at the link below. The link expires after " + 
            signedUrlValidDays + " day(s): \n" +
            signedUrl + "\n\n";
                  
    var sns = new AWS.SNS();
        
    sns.publish(
    {
        Subject: "macOS System Diagnostic Uploaded",
        Message: msg,
        TopicArn: snsTopicARN
    },

    function(err, data) 
    {
            
        if (err) 
        {
            console.log(err.stack);
            return;
        }
            
    // Debugging Junk
        console.log('Sysdiagnose srcKey and key values');
        console.log(srcKey);
        console.log('Sysdiagnose signed URL:');
        console.log(signedUrl);
        console.log(msg);
        console.log(s3Event);
        console.log('Push Sent');
            
        context.done(null, 'Function Finished!');  
          
    });
};
