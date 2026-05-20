import ballerina/http;
import ballerinax/googleapis.gmail;

final http:Client kitchenClient = check new ("https://e8f34e4e-e9bb-4799-b725-7173d271fa62-prod.e1-us-east-azure.choreoapis.dev/2on2026-ntegration/kitchenservice/v1.0");
final http:Client delivaryClient = check new ("https://e8f34e4e-e9bb-4799-b725-7173d271fa62-prod.e1-us-east-azure.choreoapis.dev/2on2026-ntegration/delivaryservice/v1.0");
final gmail:Client gmailClient = check new ({
    auth: {
        refreshToken: refreshToken,
        clientId: clientId,
        clientSecret: clientSecret
    }
});
