%% 1. Authentication & Connection
% We use the Token method (Recommended for InfluxDB v2).
% The first time you run this, MATLAB will ask for your Token.
% Currently, there isn't a viable way to retrieve a token's value from InfluxDB after its creation.

if ~isSecret("influxdbToken")
    setSecret("influxdbToken");
end

% Define connection parameters:
hostURL = "http://localhost:8086";
orgName = "Mathworks";

% Establish Connection:
try
    conn = influxdb("hostURL", hostURL, ...
        "authToken", getSecret("influxdbToken"), ...
        "org", orgName);
    disp("Successfully connected to InfluxDB at " + hostURL);
catch ME
    error("Connection Failed. Is the 'influxd' server running? " + ME.message);
end

% List existing buckets to verify connection:
disp("Current Buckets in Organization:");
listBuckets(conn, orgName)

%% 2. Data Preparation
% Create sample weather data:
MeasurementTime = datetime({'2023-12-18 08:03:05';'2023-12-18 10:03:17';'2023-12-18 12:03:13'});
Temp = [37.3; 39.1; 42.3];
Pressure = [30.1; 30.03; 29.9];
WindSpeed = [13.4; 6.5; 7.3];
ID = uint64([1; 2; 3]);
Description = repmat("Weather Data", 3, 1);
Locations = ["New York"; "Boston"; "New York"];

% Create Timetable:
TT = timetable(MeasurementTime, ID, Temp, Pressure, WindSpeed, Locations, Description);
disp("Data prepared for writing.");

%% 3. Write Data
bucketName = "write-test";
measurementName = "basic-test";

% Create bucket (Handle error if it already exists):
try
    createBucket(conn, bucketName);
    disp("Bucket '" + bucketName + "' created.");
catch
    disp("Bucket '" + bucketName + "' already exists. Proceeding...");
end

% List existing buckets to verify new bucket creation:
disp("Current Buckets in Organization:");
listBuckets(conn, orgName)

% Write the timetable to InfluxDB. We use "Locations" as a Tag (indexed), others become Fields:
writeData(conn, TT, bucketName, measurementName, "Tags", "Locations");
disp("Data written to InfluxDB.");

%% 4. Query Data
% Retrieve data using Flux query language. We filter by measurement and 'pivot' to make the table look like what MATLAB expects:
query = ['from(bucket:"write-test") |> range(start: 0) |> filter(fn: (r) => r._measurement == "basic-test")', ...
    '|> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")'];
disp("Querying data...");
T = queryData(conn, query);

% Display result:
disp("Retrieved Data:");
disp(T{1});

%% 5. Advanced Management (Bucket Info & Retention)

% Check info:
info = bucketInfo(conn, bucketName);
disp("Bucket Info retrieved.");

% Delete the bucket to clean up:
deleteBucket(conn, bucketName);
disp("Bucket '" + bucketName + "' deleted.");

% Re-create the bucket with a specific Retention Policy (e.g., Delete data automatically after ~111 hours):
retentionRules = struct("everyseconds", 4e5, "type", "expire");
createBucket(conn, bucketName, ...
    "Description", "A bucket for testing writeData function", ...
    "retentionRules", retentionRules);
disp("Re-created bucket with Retention Rules.");

% Verify new info:
bucketInfo(conn, bucketName)

%% 6. Final Cleanup
% Check connection health:
[status, message] = healthCheck(conn);
disp("Health Status: " + message);

% Delete the test bucket so we don't leave junk data:
deleteBucket(conn, bucketName);
disp("Cleanup complete. Test bucket deleted.");

% List existing buckets to verify deletion:
disp("Current Buckets in Organization:");
listBuckets(conn, orgName)
