# Credit to 'sungod' from the Meraki Forums for the initial script
# https://community.meraki.com/t5/Developers-APIs/my-first-API/m-p/178012/highlight/true#M7163

import os
import sys
import csv

import meraki.aio
import asyncio

dir_path = os.path.dirname(os.path.realpath(__file__))
csvLines = list()

#import the org id and api key from the environment
ORG_ID = os.environ.get("ORG_ID")
API_KEY = os.environ.get("API_KEY")
CSV_FILE = os.path.join(dir_path, 'meraki_bssids.csv')

async def processAp(aiomeraki: meraki.aio.AsyncDashboardAPI, ap):

    try:
        # get list of statuses for an AP
        statuses = await aiomeraki.wireless.getDeviceWirelessStatus(ap['serial'])
    except meraki.AsyncAPIError as e:
        print(f'Meraki API error: {e}', file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        print(f'some other error: {e}', file=sys.stderr)
        sys.exit(0)
    
    for bss in statuses['basicServiceSets']:
        if bss['enabled']:
            #print(f"{ap['name']},{bss['ssidName']},{bss['bssid']},{bss['band']}")
            bssid = list()
            bssid.append(ap['name'])
            bssid.append(bss['ssidName'])
            bssid.append(bss['bssid'])
            bssid.append(bss['band'])
            csvLines.append(bssid)
        
    return

async def main():
    async with meraki.aio.AsyncDashboardAPI(
        api_key=API_KEY,
        base_url='https://api.meraki.com/api/v1/',
        print_console=False,
        output_log=False,
        suppress_logging=True,
        wait_on_rate_limit=True,
        maximum_retries=100
    ) as aiomeraki:

        #get the wireless devices
        try:
            aps = await aiomeraki.organizations.getOrganizationDevices(ORG_ID, perPage=1000, total_pages="all", productTypes = ["wireless"])
        except meraki.AsyncAPIError as e:
            print(f'Meraki API error: {e}', file=sys.stderr)
            sys.exit(0)
        except Exception as e:
            print(f'some other error: {e}', file=sys.stderr)
            sys.exit(0)

        # process devices concurrently
        apTasks = [processAp(aiomeraki, ap) for ap in aps]
        for task in asyncio.as_completed(apTasks):
            await task

        print("Writing CSV file: {CSV_FILE}")
        with open(CSV_FILE, 'w') as f:
            writer = csv.writer(f)
            writer.writerows(csvLines)
        print("Finished writing CSV file!")

if __name__ == '__main__':
    asyncio.run(main())