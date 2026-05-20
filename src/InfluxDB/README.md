# MATLAB Interface for InfluxDB v2

This project demonstrates how to connect MATLAB to an InfluxDB v2 Open Source (OSS) database to write, query, and manage time-series data. It's adapted from the resources available at [Getting Started with MATLAB® Interface for InfluxDB](https://www.mathworks.com/matlabcentral/fileexchange/180619-matlab-interface-for-influxdb).

## 1. Requirements

* **MATLAB:** R2023a or later (Recommended).
* **Database Toolbox:** You must install the *Database Toolbox* via the MATLAB Add-On Manager.
* **InfluxDB OSS v2:** This interface is designed for version 2.x. (Note: It is **not** compatible with InfluxDB v3 or InfluxDB Cloud).

## 2. Installation & Setup

### Step A: Install the Database Server
1.  Execute the provided commands for **InfluxDB v2 OSS** from the [official downloads page](https://portal.influxdata.com/downloads/).
    * You may need to access further pages by scrolling to the bottom of the page.
2.  Start the Server:
    * Open your terminal or command prompt.
    * Navigate to the folder containing `influxd.exe`.
    * Run the command: `influxd`.
    * **Important:** Do not close this terminal window. The database only runs while this window is open.

### Step B: Configure the Database
1.  Open your web browser and navigate to `http://localhost:8086`.
2.  Click **Get Started** and create your initial user:
    * **Username:** `admin` (or your preference).
    * **Password:** `password` (or your preference - note that this is purely for demonstration purposes).
    * **Organization:** `Mathworks` (to match `script.m` - note that this field is case-sensitive).
    * **Initial Bucket:** `test` (Do not name it `write-test`, as the script creates that automatically).
3.  Get the **API Token**:
    * Once registered, you'll be prompted with the API Token, copy it and save it.
    * There isn't a reliable way to retrieve a given token after its creation in InfluxDB, so it's important to save a key when created.

## 3. Key Concepts & Workflow

To understand how this script works, it helps to understand the InfluxDB data model, which differs from standard spreadsheets.

### A. The Architecture
* **The Server (`influxd`):** This is the database engine running in the terminal. It listens on port `8086`. It holds the actual data.
* **The Client (MATLAB):** The script acts as a client. It sends HTTP requests (PUT/POST) to the server to send or retrieve data.

### B. The Data Hierarchy
Unlike a spreadsheet with sheets and cells, InfluxDB organizes data like this:

1.  **Organization:** The top-level workspace (e.g., "Mathworks").
2.  **Bucket:** The container for time-series data (roughly equivalent to a "Database" in SQL).
3.  **Measurement:** A logical grouping of data (roughly equivalent to a "Table"). In this script, our measurement is named `"basic-test"`.
4.  **Point:** A single data record consisting of:
    * **_time:** The primary key (always required).
    * **Tags:** Metadata strings used for grouping and filtering (e.g., `Location = "New York"`). **Tags are Indexed** (fast to search).
    * **Fields:** The actual measured values (e.g., `Temperature = 37.3`). **Fields are Not Indexed** (used for calculations).

### C. The Workflow Loop
The `script.m` file follows this standard lifecycle:
1.  **Authenticate:** Handshake with the server using the Token.
2.  **Pack:** Convert a MATLAB `timetable` into the InfluxDB Line Protocol.
3.  **Write:** Push the data to the "Bucket."
4.  **Query:** Use the **Flux** language to pull specific data back (e.g., "Show me temperature only where Location is New York").

## 4. Execution

1.  Open `script.m` in MATLAB.
2.  Run the script (either completely or by sections in order).
3.  A secure prompt will appear asking for a secret. Paste the **Token** you copied in Step B.
4.  When running the sections of the script, you'll observe:
    * Authentication.
    * Data generation.
    * Bucket creation.
    * Writing data to InfluxDB.
    * Querying data back into MATLAB.
    * Bucket deletion and retention policy management.

## 5. Troubleshooting

* **"Connection Refused" / "Could not access server":**
    Ensure the command window running `influxd` is still open. If you closed it, the server is offline. If it was open, please refer to the official [InfluxDB OSS v2 Documentation](https://docs.influxdata.com/influxdb/v2/).