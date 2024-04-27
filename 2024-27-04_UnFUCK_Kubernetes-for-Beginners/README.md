# Kubernetes for Beginners 

This is the cheat sheet for the [#UnFUCK24](https://unfuck.eu) K8S workshop.

### Prerequisites

Perform a full system upgrade

```bash
sudo apt update -y && sudo apt full-upgrade -y
```

Install necessary packages
```bash
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git
```

### Docker Setup

Downloading Docker's official GPG and adding it to the system’s list of trusted keys.

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```

Adding Docker repository to the APT sources

```bash
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable"
```

Install Docker Community Edition (CE)

```bash
sudo apt install -y docker-ce
```

Checking Docker service status

```bash
sudo systemctl status docker
```

Add the current user to the docker group (to execute docker commands)

```bash
sudo usermod -aG docker ${USER}
```

Start a new login shell to apply the group membership changes

```bash
sudo su --login ${USER}
```

Check if user is in the docker group

```bash
id
```


### Create a Cluster with “minikube”

Downloading the `minikube` Binary

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
```

Install `minikube` Binary

```bash
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

Remove `minikube` Binary (clean up)

```bash
rm minikube-linux-amd64
```

Start Minikube

```bash
minikube start
```

Activate necessary addons

```bash
minikube addons enable dashboard && \
minikube addons enable metrics-server
```

Start the Kubernetes-Dashboard

```bash
minikube dashboard --url=true &
```
### Deploy the Mutillidae II Web Application

Download the "kubectl" binary 
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```
Install the "kubectl" binary.
```bash
sudo install kubectl /usr/local/bin/kubectl
```

Remove "kubectl" Binary (clean up)

```bash
rm kubectl
```

Create a Namespace for the Mutillidae Application 
```bash
kubectl create namespace mutillidae
```

Create a deployment for each component

```bash
kubectl create deployment database-deployment --image="docker.io/webpwnized/mutillidae:database" --replicas=1 --namespace mutillidae && \
kubectl create deployment www-deployment --image="docker.io/webpwnized/mutillidae:www" --replicas=1 --namespace mutillidae && \
kubectl create deployment ldap-deployment --image="docker.io/webpwnized/mutillidae:ldap" --replicas=1 --namespace mutillidae && \
kubectl create deployment databaseadmin-deployment --image="docker.io/webpwnized/mutillidae:database_admin" --replicas=1 --namespace mutillidae && \
kubectl create deployment ldapadmin-deployment --image="docker.io/webpwnized/mutillidae:ldap_admin" --replicas=1 --namespace mutillidae
```

Checking the progress of the deployments

```bash
kubectl get deployments --namespace mutillidae --output wide --watch
```


### Expose the Web Application via Services


Expose Mutillidae Application Components

```bash
kubectl expose deployment database-deployment --name=database --type=ClusterIP --protocol=TCP --port=3306 --namespace mutillidae && \
kubectl expose deployment ldap-deployment --name=directory --type=ClusterIP --protocol=TCP --port=389 --namespace mutillidae && \
kubectl expose deployment www-deployment --name=www --type=NodePort --protocol=TCP --port=80 --namespace mutillidae && \
kubectl expose deployment databaseadmin-deployment --name=databaseadmin --type=ClusterIP --protocol=TCP --port=80 --namespace mutillidae && \
kubectl expose deployment ldapadmin-deployment --name=ldapadmin --type=ClusterIP --protocol=TCP --port=80 --namespace mutillidae
```

Scale the www-deployment

```bash
kubectl scale deployment www-deployment --replicas=2 --namespace mutillidae
````

Access www via the URL of the NodePort service type

```bash
minikube service www --namespace mutillidae
```
### Create an Ingress

Activate necessary addons

```bash
minikube addons enable ingress
```


Set the editor for editing yaml-files with kubectl
```bash
export KUBE_EDITOR="nano"
```

Edit the configuration file of the www-Service
```bash
kubectl edit service www --namespace mutillidae
```

Change the type of the www-Service (NodePort → ClusterIP)

mutillidae-ingress.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
spec:
  clusterIP: 10.110.201.6
  clusterIPs:
  - 10.110.201.6
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - port: 80 # Remove NodePort Attribute
    protocol: TCP
    targetPort: 80
  selector:
    app: www-deployment
  sessionAffinity: None
  type: ClusterIP # replace NodePort
status:
  loadBalancer: {}                      
```

Check if all service types are set to ClusterIP

```bash
kubectl get services --namespace mutillidae --output wide
```

### Create a  Ingress-Configuration for the Mutillidae Application

Define the specifications for the mutillidae-ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mutillidae-ingress
  namespace: mutillidae
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: www.mutillidae.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: www
                port:
                  number: 80
    - host: databaseadmin.mutillidae.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: databaseadmin
                port:
                  number: 80
    - host: ldapadmin.mutillidae.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ldapadmin
                port:
                  number: 80
```

Get your minikube ip

```bash
minikube ip
```

Edit the hosts file for a local DNS resolution

```bash
sudo nano /etc/hosts
```

Map your minikube ip to the necessary URLs

```plaintext
127.0.0.1       localhost
127.0.1.1       ubuntu
192.168.49.2    databaseadmin.mutillidae.com
192.168.49.2    ldapadmin.mutillidae.com
192.168.49.2    www.mutillidae.com
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6

-allnodes
ff02::2 ip6-allrouters
```

Check if the modification was successful

```bash
nslookup $(minikube ip)
```

Apply the configured Ingress

```bash
kubectl apply -f mutillidae-ingress.yaml
````

Access the Web-Application by visiting www.mutillidae.com

### Hacking Mutillidae II

Visit [http://www.mutillidae.com/index.php?page=dns-lookup.php](http://www.mutillidae.com/index.php?page=dns-lookup.php)

Understand what happens after starting the DNS-Lookup in the Mutillae Web Application

Use dnslookup to compare the output
```bash
nslookup localhost
```

## Discover the Filesystem of the Container

Check current user
```bash
; whoami
```

List content of root directory
```bash
; ls -l /
```

Display the Environment Variables
```bash
; env
```

Check for mounted secrets within the container

```bash
; ls /var/run/secrets/kubernetes.io/serviceaccount
```

Decode and print the client certificate

```bash
; cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

Decode and print the users token

```bash
; cat /var/run/secrets/kubernetes.io/serviceaccount/token | base64 --decode
```

### Attach a Volume to the Pod

Create a virtual hard disk

```bash
dd if=/dev/zero of=virtual-disk.img bs=1M count=1024
```

Create a persistent volume (PV)

**www-virtual-disk-pv.yaml**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: www-virtual-disk-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: ~/virtual-disk.img
```

```bash
kubectl apply -f www-virtual-disk-pv.yaml
```

Create a persistent volume claim for the virtual disk

**www-virtual-disk-pvc.yaml**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: www-virtual-disk-pvc
  namespace: mutillidae
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```bash
kubectl apply -f www-virtual-disk-pvc.yaml
```

Create a Secret to save credentials

**www-admin-secret.yaml**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: www-admin-secret
  namespace: mutillidae
type: Opaque
data:
  username: YWRtaW4=
  password: YWRtaW5wYXNz
```

```bash
kubectl apply -f www-admin-secret.yaml
```

Edit the www-deployment Configuration to mount the Volume

```bash
kubectl edit deployment www-deployment --namespace mutillidae
```

**www-deployment.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  creationTimestamp: "2024-04-22T10:44:42Z"
  generation: 1
  labels:
    app: www-deployment
  name: www-deployment
  namespace: mutillidae
  resourceVersion: "26862"
  uid: 42722778-7d16-47af-a1de-fbd63d580ade
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: www-deployment
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: www-deployment
    spec:
      containers:
      - image: docker.io/webpwnized/mutillidae:www
        imagePullPolicy: IfNotPresent
        name: mutillidae
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File

        #################################
        volumeMounts:
        - name: www-virtual-disk
          mountPath: /var/www/html
        - name: secret
          mountPath: /etc/secrets
          readOnly: true
      volumes:
      - name: www-virtual-disk
        persistentVolumeClaim:
          claimName: www-virtual-disk-pvc
      - name: secret
        secret:
          secretName: www-admin-secret
      #################################

      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
status:
  availableReplicas: 1
  conditions:
  - lastTransitionTime: "2024-04-22T10:44:44Z"
    lastUpdateTime: "2024-04-22T10:44:44Z"
    message: Deployment has minimum availability.
    reason: MinimumReplicasAvailable
    status: "True"
    type: Available
  - lastTransitionTime: "2024-04

-22T10:44:43Z"
    lastUpdateTime: "2024-04-22T10:44:44Z"
    message: ReplicaSet "www-deployment-698c8bb8f5" has successfully progressed.
    reason: NewReplicaSetAvailable
    status: "True"
    type: Progressing
  observedGeneration: 1
  readyReplicas: 1
  replicas: 1
  updatedReplicas: 1
```



### Implements Role Based Access Controls


Create ServiceAccount for the www-Service

```bash
kubectl create serviceaccount www-user-sa --namespace mutillidae
```

Create the user role for the www-service

**www--user-role.yaml**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: www-user-role
  namespace: mutillidae
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["www-admin-secret"]
  verbs: ["get", "watch", "list"]
```

```bash
kubectl apply -f www-user-role.yaml
```

Bind the user role to the serviceaccount

**www-user-rolebinding.yaml**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: www-user-rolebinding
  namespace: mutillidae
subjects:
- kind: ServiceAccount
  name: www-user-sa
  namespace: mutillidae
roleRef:
  kind: Role
  name: www-user-role
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f www-user-rolebinding.yaml
```
