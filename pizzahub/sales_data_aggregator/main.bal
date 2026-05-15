import ballerina/ftp;
import ballerina/log;
import ballerina/sql;
import ballerina/time;

public function main() returns error? {
    // Get today's date for query filtering and file naming
    // Format: "YYYY-MM-DDThh:mm:ssZ" — extract the first 10 characters for the date
    string utcString = time:utcToString(time:utcNow());
    string dateStr = utcString.substring(0, 10);

    log:printInfo("Starting sales data export", date = dateStr);

    // Query today's orders from the database
    stream<Order, sql:Error?> orderStream = dbClient->query(
        `SELECT order_id, customer_name, customer_email, item_name, quantity, total_price, order_status, order_date
         FROM orders
         WHERE DATE(order_date) = ${dateStr}`
    );

    // Collect orders into an array
    Order[] orders = check from Order salesOrder in orderStream
        select salesOrder;

    if orders.length() == 0 {
        log:printInfo("No orders found for today, skipping CSV upload", date = dateStr);
        return;
    }

    log:printInfo("Fetched orders for export", count = orders.length(), date = dateStr);

    // Build CSV rows: header + data rows
    string[][] csvRows = [["order_id", "customer_name", "customer_email", "item_name", "quantity", "total_price", "order_status", "order_date"]];
    foreach Order salesOrder in orders {
        string[] dataRow = [
            salesOrder.order_id.toString(),
            salesOrder.customer_name,
            salesOrder.customer_email,
            salesOrder.item_name,
            salesOrder.quantity.toString(),
            salesOrder.total_price.toString(),
            salesOrder.order_status,
            salesOrder.order_date
        ];
        csvRows.push(dataRow);
    }

    // Upload CSV to FTP with a date-stamped filename
    string fileName = string `sales_${dateStr}.csv`;
    string remotePath = string `${ftpUploadPath}/${fileName}`;

    check ftpClient->putCsv(remotePath, csvRows, option = ftp:OVERWRITE);

    log:printInfo("Sales CSV uploaded successfully", fileName = fileName, remotePath = remotePath, rowCount = orders.length());
}
