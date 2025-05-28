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
- Find the pdf report for the year identified in the script
- Downloads and hashes the PDF
- Compares it to the previous PDF hash created by the script
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
/logs Stores the change_log
change_log.txt	Append-only log of monitoring results
/output Stores all output files (below)
dca_temp.html html code extracted from dca website

latest.pdf	Most recently downloaded report
pdf_hash.txt	Stores last known hash & timestamp



🛡️ Error Handling
Separate exitcodes and NTFY notifications:
- If no text matching the year you are searching for is found
- If a match is found but there is no PDF file linked
- If the download of the PDF file failes
- If there is no previous hash indicating this is the first time the script is running
- If the PDF is hashed but no change was detected
- If the PDF is hased and a change is detected.

📦 Dependencies
Make sure these are available:

-curl
-awk or gawk
-printf
-sha256sum
-ntfy.sh (no install needed — it's just a POST request to a public service)

👤 Author
netzbrrr
https://github.com/netzbrrr
