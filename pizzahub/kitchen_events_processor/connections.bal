import ballerina/http;

// HTTP clients for the three downstream endpoints
final http:Client customerNotificationClient = check new (customerNotificationEndpoint);
final http:Client posSystemClient = check new (posSystemEndpoint);
final http:Client analyticsClient = check new (analyticsEndpoint);
