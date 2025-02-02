# Network IP and Port Scanner for local use

## Description

This Python script retrieves all IPv4 addresses of available network interfaces
and scans for open ports in a specified range.

## Features

- Lists all IPv4 addresses assigned to network interfaces.
- Scans for open ports within a defined range.

## Requirements

- Python 3.x
- psutil library (install with pip install psutil)

## Usage

 1. Clone the repository or download the script.
 2. Install dependencies if needed:
    `pip3 install psutil`
 3. Run the script:
    `python3 script.py`

## Configuration

- Modify start_port and end_port to change the scanning range.

## Example Output

```sh
Open ports for 192.168.1.10: [22, 80, 443]
No open ports on 192.168.1.11 in range 1-1024
```

## License

This project is licensed under the MIT License.
