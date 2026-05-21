* Add favicon
* Fix "not secure website" when browsing on https://user1.campto.camp/
* Simplify instructions for kubectl installation
* Improve integration with existing kubeconfig, try to import downloaded kubeconfig into ~/.kube/config with a fency kubectl command. Add slides to warn about already existing ~/kube/config (create 2 scenario: with or without default kubeconfig)
* fix revoke old kubeconfig on each terragrunt apply: the setup-user.sh script seems to invalidate the kubeconfig on each run
* Add link to the CNPG API docs  https://cloudnative-pg.io/docs/1.28/cloudnative-pg.v1
* Use a unique HTML page/file for each participants but adapt placeholder using
  javascript using the URL as source: *user1*.campto.camp, token can be download
  by js using xhr: user1.campto.camp/token
* simplify token copy: button should copy token to clipboard instead of
  displaying the token
* lab2: during presentation show, label usage for primary: cnpg.io/instanceRole: primary, a lifecycle of instance linked to a imagecatalog
* lab1: during presentation show 'ready status': define micro lb config: prod-r,
  prod-ro, prod-rw

# Instructions

## Lab 1 -- Deploy a Cluster


### Create a cluster

* In a new folder, create a lab1.yaml file with :

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: prod
spec:
  instances: 3
  storage:
    size: 2Gi
```

* Deploy the manifest

```shell
kubectl apply -f lab1.yaml
```

### Inspect Kubernetes objects

```shell
kubectl get pod,service,secret,pvc -l "app.kubernetes.io/managed-by=cloudnative-pg"
```

### Check cluster status

```shell
kubectl get cluster
kubectl cnpg status prod # check timeline: 1
```

### Connect to the cluster

```shell
kubectl cnpg psql prod
```

### Kill replica or primary

```shell
kubectl delete pod prod-3 # kill a replica

kubectl delete pod prod-1 # kill the primary
kubectl cnpg status prod  # notice timeline increment: 2

# Kill all cluster pods
kubectl delete pod -l "app.kubernetes.io/managed-by=cloudnative-pg"
```



## Lab 2 -- PostgreSQL Anonymizer

### Inspect ClusterImageCatalog

```shell
kubectl describe clusterimagecatalog
```

### Cleanup previous cluster

```shell
kubectl delete cluster prod
```

### Deploy a new cluster with PostgreSQL Anonymizer

Create a file `prod-anon.yaml`:

``` yaml
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: prod
spec:
  instances: 3
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: camptocamp
    major: 18
  postgresGID: 999 # initdb: could not look up effective user ID 26: user does not exist
  postgresUID: 999
  postgresql:
    pg_hba:
      - host all all all trust
      - host replication all all trust
  storage:
    size: 2Gi
  bootstrap:
    initdb:
      postInitSQL:
        - |
          ALTER DATABASE postgres
            SET session_preload_libraries = 'anon';
          CREATE EXTENSION anon;
          ALTER DATABASE postgres
            SET anon.transparent_dynamic_masking TO true;
```

```shell
kubectl apply -f prod-anon.yaml
```

* Create a `people` table:

```shell
kubectl cnpg psql prod
```

```sql
CREATE TABLE people AS
    SELECT  153478       AS id,
            'Sarah'      AS firstname,
            'Conor'      AS lastname,
            '0609110911' AS phone;
```

* Define masking rules:

```sql
SECURITY LABEL FOR anon ON COLUMN people.lastname
  IS 'MASKED WITH FUNCTION anon.dummy_last_name()';

SECURITY LABEL FOR anon ON COLUMN people.phone
  IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```

* Create a masked user

```sql
CREATE ROLE skynet LOGIN;

SECURITY LABEL FOR anon ON ROLE skynet IS 'MASKED';

GRANT pg_read_all_data to skynet;
```

* Connect with the 'skynet' role

```shell
kubectl cnpg psql prod -- -h localhost --username skynet postgres
```

.note The `local` policy in `pg_hba.conf` is managed by CNPG so `peer`
connection cannot be used for `skynet` role

* Inspect data

```sql
TABLE people;
```

## Lab 3 -- Bootstrap Data


Create a `lab3.yaml` file with a new Cluster definition compatible with PostgreSQL Anonymizer:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: prod-copy-green
spec:
  instances: 1
  storage:
    size: 2Gi
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: camptocamp
    major: 18
  postgresGID: 999 # initdb: could not look up effective user ID 26: user does not exist
  postgresUID: 999
```  

Inspect kubernetes service associated to the `prod` cluster:

```shell
kubectl get service -l 'cnpg.io/cluster=prod'
```

Because `pg_dump` need to acquire lock for a dump we will use the `prod-rw` endpoint.
We will use the masked role for the data extraction: `skynet`.
So please add the following `externalClusters` section to the `lab3.yaml` file:

```yaml
  externalClusters:
    - name: prod
      connectionParameters:
        host: prod-rw
        user: skynet
        dbname: postgres
```

Finally, we will define the `bootstrap` section :

```yaml
  bootstrap:
    initdb:
      import:
        type: monolith
        databases:
          - postgres
        source:
          externalCluster: prod
        pgDumpExtraOptions:
          - --no-owner
          - --no-privileges
...


The `pg_dump` options ensure that there is no error related to missing role.

The cluster can be deployed with:

```shell
kubectl apply -f lab3.yaml
```

An `prod-copy-green-init` pod is responsible of launching `initdb` and then `pg_dump`/`pg_restore` as describe.


## Lab 4 -- Replica Pool


### Inspect replication secrets created by the 'prod' cluster

```shell
kubectl get secret -l app.kubernetes.io/managed-by=cloudnative-pg
```

* `prod-app` credentials for the `app` role (user, password, uri)
* `prod-ca` certificate authority for servers and certificate based roles (replication)
* `prod-server` server certificate
* `prod-replication` certificate for streaming replication authentification

Try a connection with the default applicative role `app`:

```shell
export PROD_APP_URI=$(kubectl get secret prod-app -o jsonpath='{.data.uri}' | base64 -d)
echo ${PROD_APP_URI}
kubectl run psql --rm -it --image=ghcr.io/camptocamp/postgres:18 --restart=Never -- psql $PROD_APP_URI
```

For our new blue copy of the `prod` cluster we will use the builtin replication role : `streaming_replica`

```shell
kubectl get secret prod-replication -o yaml
```

This secret can be used in the `spec.externalClusters`:

```yaml
  externalClusters:
    - name: prod
      connectionParameters:
        host: prod-rw
        user: streaming_replica
        sslmode: verify-full
      sslKey:
        name: prod-replication
        key: tls.key
      sslCert:
        name: prod-replication
        key: tls.crt
      sslRootCert:
        name: prod-ca
        key: ca.crt
```

Then we need the `bootstrap` and `replica` sections:

```yaml
  replica:
    enabled: true
    source: prod
  bootstrap:
    pg_basebackup:
      source: prod
```

At the end you should have something similar to:

```yaml
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: prod-copy-blue
spec:
  instances: 1
  storage:
    size: 2Gi
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: camptocamp
    major: 18
  postgresGID: 999
  postgresUID: 999
  replica:
    enabled: true
    source: prod
  bootstrap:
    pg_basebackup:
      source: prod
  externalClusters:
  - name: prod
    connectionParameters:
      host: prod-rw
      user: streaming_replica
      sslmode: verify-full
    sslKey:
      name: prod-replication
      key: tls.key
    sslCert:
      name: prod-replication
      key: tls.crt
    sslRootCert:
      name: prod-ca
      key: ca.crt
...
```