import ballerina/ftp;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// MySQL client for querying sales orders
final mysql:Client dbClient = check new (
    host = dbHost,
    user = dbUser,
    password = dbPassword,
    database = dbName,
    port = dbPort
);

// FTP client for uploading the generated CSV
final ftp:Client ftpClient = check new ({
    protocol: ftp:FTP,
    host: ftpHost,
    port: ftpPort,
    auth: {
        credentials: {
            username: ftpUser,
            password: ftpPassword
        }
    }
});
