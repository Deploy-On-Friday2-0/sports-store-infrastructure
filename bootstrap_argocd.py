import os
import sys
import subprocess
import json

cluster_name = sys.argv[1]
region = sys.argv[2]
deployments_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "sports-store-deployments"))

def run_cmd(args, check=True):
    print(f"Running: {' '.join(args)}")
    res = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        print(f"Error executing command: {res.stderr}")
        if check:
            sys.exit(res.returncode)
    else:
        print(res.stdout)
    return res.returncode, res.stdout, res.stderr

# 1. Update kubeconfig
run_cmd(["aws", "eks", "update-kubeconfig", "--name", cluster_name, "--region", region])

# 2. Add and update Argo Helm Repository
run_cmd(["helm", "repo", "add", "argo", "https://argoproj.github.io/argo-helm"])
run_cmd(["helm", "repo", "update"])

# 3. Extract Helm values from sports-store-deployments/bootstrap/argocd.yaml
argocd_yaml_path = os.path.join(deployments_dir, "bootstrap", "argocd.yaml")
if not os.path.exists(argocd_yaml_path):
    print(f"Error: Could not find bootstrap configuration at {argocd_yaml_path}")
    sys.exit(1)

print(f"Parsing helm values from {argocd_yaml_path}...")
helm_values_lines = []
inside_values = False
indentation = None

with open(argocd_yaml_path, "r", encoding="utf-8") as f:
    for line in f:
        if "values: |" in line:
            inside_values = True
            continue
        if inside_values:
            stripped = line.lstrip()
            if not stripped:
                helm_values_lines.append(line)
                continue
            
            current_indent = len(line) - len(stripped)
            if indentation is None:
                indentation = current_indent
            
            if current_indent < indentation:
                # Reached end of values block
                break
            
            helm_values_lines.append(line[indentation:])

helm_values = "".join(helm_values_lines)
temp_values_path = os.path.join(os.path.dirname(__file__), "temp-argocd-values.yaml")

print(f"Writing extracted values to temporary file {temp_values_path}...")
with open(temp_values_path, "w", encoding="utf-8") as f:
    f.write(helm_values)


# 4. Install Argo CD via Helm
try:
    helm_cmd = [
        "helm", "upgrade", "--install", "argocd", "argo/argo-cd",
        "--namespace", "argocd",
        "--create-namespace",
        "--version", "10.2.2",
        "--values", temp_values_path,
        "--include-crds"
    ]
    run_cmd(helm_cmd)
finally:
    # Clean up temporary values file
    if os.path.exists(temp_values_path):
        os.remove(temp_values_path)

# 5. Apply projects and applications
project_path = os.path.join(deployments_dir, "projects", "sports-store-project.yaml")
root_app_path = os.path.join(deployments_dir, "apps", "root-app.yaml")

run_cmd(["kubectl", "apply", "-f", project_path])
run_cmd(["kubectl", "apply", "-f", root_app_path])

print("Argo CD bootstrapping completed successfully!")
