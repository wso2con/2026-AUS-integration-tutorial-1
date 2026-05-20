import ballerina/http;
import ballerina/log;
import ballerina/uuid;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service /pizza on httpDefaultListener {
    resource function post orders(@http:Payload PizzaOrderRequest payload) returns PizzaOrderResponse|error {
        do {
            log:printInfo("Order Received");
            string orderId = payload.customerId + uuid:createType1AsString();
            KitchenOrderRequest kitchenOrder = transform(payload, orderId);
            KitchenOrderResponse kitchenRes = check kitchenService->/orders.post(kitchenOrder);
            DeliveryResponse delivaryRes = check delivaryService->/quotes.get(orderId = orderId, address = payload.address);
            if kitchenRes.status == "ACCEPTED" {
                PizzaOrderResponse res = {orderId, status: kitchenRes.status, estimatedReadyTime: kitchenRes.etaMinutes, deliveryPartner: delivaryRes.deliveryPartner, deliveryEtaMinutes: delivaryRes.etaMinutes};
                log:printInfo("sending");
                _ = check gmailClient->/users/[pizzaHubEmail]/messages/send.post({
                    to: [payload.email],
                    'from: pizzaHubEmail,
                    subject: "PizzaHub Order Status",
                    bodyInText: string `Order id ${orderId} status : ${kitchenRes.status}`
                });
                return res;
            } else {
                return error("Order failed");
            }

        } on fail error err {
            // handle error
            return error("unhandled error", err);
        }
    }

}
