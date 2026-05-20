
function transform(string orderId, OrderRequest payload) returns KitchenRequest => {
    orderId: orderId + payload.customerId,
    items: payload.items
};
