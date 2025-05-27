# DCA PDF Monitor

A Bash script that monitors the **Department of Civil Aviation Myanmar** (DCA) website for newly published PDF reports. If a change is detected, it logs the update and sends a push notification via [ntfy.sh](https://ntfy.sh).

The Department of Civil Aviation in Myanmar publishes aggregated monthly data on the number of people that travel by Airplane. 
The data is based on the flight manifests and shows for each of the Domestic and International Airports the total number of passengers (and cargo).
Dat is split between departed and arrived number of people for each of the Airports in any given month. 
The data is published on the website dca.gov.mm, but there is no fixed frequency in which it is updated. 
There also is no notification function offered by dca.gov.mm. 
This script will automatically compare the current data publication pdf on dca.gov.mm to the previously checked version in order to signal a change.
Thereby signaling if new data was added and removing the need to manually check the website.

---

## 📌 What It Does

- Scrapes the [DCA Myanmar Publications Page](https://dcamyanmar.com/dcadca/index.php?option=com_content&view=article&id=29)
- Extracts the latest `YYYY-MMM`-formatted PDF link
- Downloads and hashes the PDF
- Compares it to the last known version
- Logs the results
- Sends a notification via NTFY to the topic "DCA_Data_Update" to inform if a difference in the PDF (name and/or content) was detected
- If the link text on the website is not updated, but the linked pdf is updated, then a change will still be detected.

---

## 🚀 Usage

```bash
bash check_dca.sh
This script can be automated with cron or systemd to check periodically.

🔔 Notifications
Uses ntfy.sh to send push messages.

By default, the topic is: https://ntfy.sh/DCA_Data_Update

You can subscribe to it from the web or a mobile app.

📂 Output Files
File	Purpose
/var/local/dca_monitor/	All persistent data stored here
latest.pdf	Most recently downloaded report
pdf_hash.txt	Stores last known hash & timestamp
change_log.txt	Append-only log of monitoring results
last_check.txt	(Reserved, optional for future use)

🛡️ Error Handling
If no valid PDF link is found, a message is logged and sent.

If the PDF fails to download, it notifies and exits.

Uses sha256sum for change detection.

📦 Dependencies
Make sure these are available:

-curl
-awk or gawk
-sha256sum
-ntfy.sh (no install needed — it's just a POST request to a public service)

👤 Author
netzbrrr
https://github.com/netzbrrr
