// Order record matching the orders table schema
type Order record {|
    int order_id;
    string customer_name;
    string customer_email;
    string item_name;
    int quantity;
    decimal total_price;
    string order_status;
    string order_date;
|};
