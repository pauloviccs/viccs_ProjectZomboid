import subprocess

jar = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar"
res = subprocess.run(["javap", "-cp", jar, "-c", "-p", "zombie.inventory.ItemContainer"], capture_output=True, text=True, errors="ignore")
out = res.stdout
idx = out.find("getItemWithID(int)")
if idx != -1:
    print(out[idx:idx+1000])
