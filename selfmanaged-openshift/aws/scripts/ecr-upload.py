import shutil, os.path, re, sys, subprocess

binname = "./cpd-cli"
if len(sys.argv) != 6:
    print("Usage: python ecr-upload.py 'lite,wkc', <aws_repo_name>, <aws_region>, <aws_ecr_username>, <aws_ecr_password>")
    sys.exit(1)

services = str(sys.argv[1])
repo = sys.argv[2]
region = sys.argv[3]
username = sys.argv[4]
password = sys.argv[5]

servicesList = services.split(",")
#if repo.yaml exists
if os.path.isfile("repo.yaml") is False:
    print("repo.yaml not present in folder")
    sys.exit(1)

#if cpd-cli is available
if os.path.isfile("cpd-cli"):
    print("cpd-cli present in folder")
else:
    print("cannot find cpd-cli, checking PATH")
    if shutil.which("cpd-cli") is None:
        print("cpd-cli not found in PATH..Download cpd-cli https://github.com/IBM/cpd-cli/releases")
        sys.exit(1)
    else:
        binname = "cpd-cli"
if shutil.which("aws") is None:
    print("aws not found in PATH. Install and Configure awscli")
    sys.exit(1)

print("Getting the list of images required")

def extractImages(result):
    resultList = result.split('\n')
    imagelist = resultList[1:] #drop the header
    images = []
    for imagestring in imagelist:
        if len(imagestring) > 5 and "--" not in imagestring and "*" not in imagestring:
            imagetag = ":".join(imagestring.split())
            images.append(imagetag)
    return images


imageList = []
for service in servicesList:
    first = [binname, "preload-images", "-a", service, "-r", "repo.yaml", "--dry-run", "--accept-all-licenses"]
    second = ["awk", "/^REPO/,0"]
    p1 = subprocess.Popen(first, stdout=subprocess.PIPE)
    p2 = subprocess.Popen(second, stdin=p1.stdout, stdout=subprocess.PIPE)
    out, err = p2.communicate()
    if err is None:
        images = extractImages(out.decode("utf-8"))
        imageList += images
    else:
        print("Error downloading image list from repo server")
print(imageList)


# Create (if repo doesnt exist), and push to repo
def isRepoValid(reponame, region):
    result = subprocess.run(["aws", "ecr", "describe-repositories", "--repository-names", reponame, "--region", region])
    if result.returncode == 0:
        return True
    return False

def createEcrRepo(reponame, region):
    result = subprocess.run(["aws", "ecr", "create-repository", "--repository-name", reponame, "--region", region])
    if result.returncode == 0:
        print("Repo: " + reponame + " created successfully")
    else:
        print(str(result.stdout))
        sys.exit(1)

for image in imageList:
    reponame = image.split(":")[0]
    if isRepoValid(reponame, region) is False:
        createEcrRepo(reponame, region)
for service in servicesList:
    command = [binname, "preload-images", "-a", service, "-r", "repo.yaml", "--action=transfer", "--transfer-image-to="+repo, "--target-registry-username="+username, "--target-registry-password="+password, "--accept-all-licenses"]
    subprocess.Popen(command).wait()
