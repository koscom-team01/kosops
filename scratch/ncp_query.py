import os
import sys
import time
import hashlib
import hmac
import base64
import requests

# Read keys from environment
access_key = os.environ.get("NCP_ACCESS_KEY")
secret_key = os.environ.get("NCP_SECRET_KEY")

if not access_key or not secret_key:
    print("Error: NCP_ACCESS_KEY and NCP_SECRET_KEY environment variables must be set.")
    sys.exit(1)

def make_signature(method, uri, timestamp, access_key, secret_key):
    message = method + " " + uri + "\n" + timestamp + "\n" + access_key
    message = bytes(message, 'utf-8')
    secret_key = bytes(secret_key, 'utf-8')
    signing_key = hmac.new(secret_key, message, digestmod=hashlib.sha256).digest()
    signature = base64.b64encode(signing_key).decode('utf-8')
    return signature

def call_ncp_api(action, params=None):
    timestamp = str(int(time.time() * 1000))
    uri = f"/vserver/v2/{action}"
    
    # Financial Cloud API Gateway base URL
    base_url = "https://ncloud.apigw.fin-ntruss.com"
    url = base_url + uri
    
    headers = {
        "Content-Type": "application/json",
        "x-ncp-apigw-timestamp": timestamp,
        "x-ncp-iam-access-key": access_key,
        "x-ncp-apigw-signature-v2": make_signature("GET", uri + ("?" + "&".join([f"{k}={v}" for k, v in params.items()]) if params else ""), timestamp, access_key, secret_key)
    }
    
    response = requests.get(url, headers=headers, params=params)
    return response.json()

print("--- Querying Server Images ---")
try:
    images_res = call_ncp_api("getServerImageProductList")
    images = images_res.get("getServerImageProductListResponse", {}).get("serverImageProductList", [])
    
    if not images:
        print("Raw API Response:")
        print(images_res)
        
    rocky_images = [img for img in images if "Rocky" in img.get("productName", "")]
    
    for img in rocky_images[:10]:
        print(f"Code: {img.get('productCode')}, Name: {img.get('productName')}, Platform: {img.get('platformType', {}).get('code')}")
        
    if not rocky_images:
        print("No Rocky Linux images found. All images:")
        for img in images[:15]:
            print(f"Code: {img.get('productCode')}, Name: {img.get('productName')}")
            
    # Use the first Rocky image or first general image for testing products
    target_img_code = rocky_images[0].get("productCode") if rocky_images else (images[0].get("productCode") if images else None)
    
    if target_img_code:
        print(f"\n--- Querying Server Products for Image: {target_img_code} ---")
        # Query products in FKR-1 zone
        products_res = call_ncp_api("getServerProductList", {
            "serverImageProductCode": target_img_code,
            "regionCode": "FKR",
            "zoneCode": "FKR-1"
        })
        products = products_res.get("getServerProductListResponse", {}).get("serverProductList", [])
        
        # Filter for 2vCPU standard specs
        filtered_products = [p for p in products if p.get("cpuCount") == 2 and "STAND" in p.get("productCode", "")]
        for p in filtered_products[:15]:
            print(f"Code: {p.get('productCode')}, Name: {p.get('productName')}, CPU: {p.get('cpuCount')}, RAM: {p.get('memorySize')/1024/1024/1024}GB")
            
        if not filtered_products:
            print("No 2vCPU standard products found. All products:")
            for p in products[:15]:
                print(f"Code: {p.get('productCode')}, Name: {p.get('productName')}")
except Exception as e:
    print(f"Error calling NCP API: {e}")
