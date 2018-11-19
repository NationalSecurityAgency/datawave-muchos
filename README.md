<p align="center">
   <a href="https://github.com/NationalSecurityAgency/datawave">
     <img src="https://github.com/NationalSecurityAgency/datawave/blob/master/datawave-readme.png" />
   </a>
</p>
<p align="center">
   Powered by
   <a href="https://github.com/apache/fluo-muchos">
     <img src="https://github.com/apache/fluo-muchos/blob/master/contrib/muchos-logo.png" alt="Muchos" height="15" />
   </a>
   &nbsp;and&nbsp;
   <a href="https://www.ansible.com">Ansible
     <img src="https://www.ansible.com/hubfs/red-hat-ansible.svg" alt="Ansible" height="15" />
   </a>
</p>

[![Apache License][li]][ll]

## Purpose

This project is intended to be used in tandem with [Muchos][muchos] to automate the deployment
of [DataWave][datawave] for development and testing purposes on a cluster of arbitrary size.

The project is comprised primarily of [Ansible][ansible] scripts, which are intended to be used on your cluster
*after* Muchos setup has been completed. Thus, users will first employ Muchos independently to establish DataWave's
base dependencies (Hadoop, Accumulo, and ZooKeeper) and to establish the base Ansible inventory required to
automate configuration and deployment of DataWave.

**Compatibility Notes**
   
Testing/verification has been performed on AWS using the following
   
| Muchos Commit | Configuration | DataWave Commit |
|----------|---------|---------|
| [6e786a0](https://github.com/apache/fluo-muchos/commit/6e786a0f43e4be01ce15fe1bf9fc7aeafd46739f) | [muchos.props.example](muchos.props.example) | [116e1f8](https://github.com/NationalSecurityAgency/datawave/commit/116e1f87e2879fea498a76b4903e578cc6a06dda) |

**Prerequisites / Assumptions**

* Familiarity with the basics of Ansible is recommended but not required
* Familiarity with the following is assumed
  * Hadoop HDFS and MapReduce
  * Accumulo and ZooKeeper
  * DataWave
  * Muchos (see Muchos documentation for prerequisites)

## Get Started

1. Use [Muchos][muchos] to set up your cluster.

   If desired, you can have Muchos launch dedicated EC2 hosts for DataWave's ingest master and web
   server(s) by adding them as nodes of type *client* in your **muchos.props** as follows:
   ```
     ...
     [nodes]
     ...
     ingest1 = client
     webserver1 = client
     
   ```
   Muchos will install and configure base dependencies on client nodes, but no service daemons will be activated.
   
   

2. When Muchos setup is complete, ssh to your proxy host and clone this repository.
   For example:
   ```bash
   <me@localhost>$ cd /path/to/fluo-muchos
   <me@localhost>$ bin/muchos ssh
   ...
   <cluster_user@leader1>$ git clone https://github.com/NationalSecurityAgency/datawave-muchos.git
   ```
   Remaining tasks below should be performed on the proxy host as the user denoted by your
   `cluster_user` variable.
   
3. Symlink your Muchos inventory and assign your DataWave-specific hosts in the *dw-hosts* file.
   ```bash
   $ cd datawave-muchos/ansible/inventory

   # 3.1 - Create symlink to your Muchos hosts file
   $ ln -s /home/cluster_user/ansible/conf/hosts muchos-hosts

   # 3.2 - Edit the DataWave inventory file as needed
   $ vi dw-hosts
     ...   
   ```
   This allows us to pass the *inventory* directory itself as an argument to Ansible, e.g., `ansible-playbook -i inventory/ ...`,
   which tells Ansible to merge all files present into a single inventory automatically.
   
   At this point, you should have only two files in the directory, *muchos-hosts* and *dw-hosts*.
   
4. Configure your *all* group and *datawave* group variables.
   ```bash
   $ cd datawave-muchos/ansible/group_vars

   # 4.1 (Required) - Symlink the Muchos 'all' vars file
   $ ln -s /home/cluster_user/ansible/group_vars/all all

   # 4.2 (Optional) - Set DataWave-specific overrides in the 'datawave' vars file
   $ vi datawave
     ...
   ```
   * Generally, you'll find variables and their default values defined in *ansible/roles/{{ role name }}/defaults/main.yml*,
     so that they can be easily overridden (values assigned there receive the lowest possible precedence in Ansible)

   * Most of the variables you'll care about are here: [ansible/roles/common/defaults/main.yml](ansible/roles/common/defaults/main.yml)
   
   * Often, you'll find it convenient to override variables from the command line via Ansible's `-e / --extra-vars`
     option, as demonstrated below in [post-deployment/force redeploy](#force-redeploy)
     
5. Lastly, build/deploy DataWave with the [datawave.yml](ansible/datawave.yml) playbook.
   ```bash
   $ cd datawave-muchos/ansible
   $ ansible-playbook -i inventory datawave.yml

   # Or equivalently...
   $ scripts/dw-play.sh
   ```
   * The *dw-build* role will first git-clone a remote DataWave repository on your proxy host, as configured by the
     following variables: `dw_repo`, `dw_clone_dir`, `dw_checkout_version`
     
   * **Note**: To build DataWave's ingest and web tarballs, the proxy host will need a few GB free on the volume containing
     the local git repo. Additionally, you'll need a few GB free for the local Maven repo. For EC2 clusters,
     depending on the source AMI and storage configuration, you may need to
     [attach and mount a volume](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-attaching-volume.html) large enough
     to accomodate these directories, configured via `dw_clone_dir` and `dw_m2_repo_dir` respectively
   
## Post-Deployment

Additional playbooks are provided as a convenience to simplify common post-deployment tasks on your cluster.
These are described below. Also note that the *datawave.yml* playbook imports [post-deployment.yml](ansible/post-deployment.yml)
to allow you to run many of these tasks automatically after DataWave has been installed. In general, tasks in
*post-deployment.yml* will be conditionally activated based on the value of one or more boolean variables, which you may
override as needed.

#### DataWave Query Client

If `dw_install_web_client` was set to `True` (default), then a simple, curl-based query client for DataWave
will have been installed and configured on your proxy host.

The client will simplify your interaction with the DataWave Query API by...

* automatically configuring test PKI materials and associated curl parameters
* setting reasonable defaults for DataWave-specific parameters
* automatically pretty-printing web service responses based on their content type
* automatically closing queries when response code 204 is returned (no results found)
* etc

For example:
```bash
 $ which datawave || source ~/.bashrc
 ...
 $ datawave query --expression "PAGE_TITLE:AccessibleComputing" --show-meta
 {
   "Events": [
       {
         ...
       }
   ], 
   ...
   "ReturnedEvents": 1
 }
 Query ID: 51082ed4-b579-45b8-879f-3afdb10e6ec3
 Time: 0.271 Response Code: 200 Response Type: application/json
 
 $ datawave query --next 51082ed4-b579-45b8-879f-3afdb10e6ec3 --show-meta
 Time: 0.093 Response Code: 204 Response Type: N/A
 [DW-INFO] - End of result set, as indicated by 204 response. Closing query automatically
 ...
```
* Query Client options: `$ datawave query --help`
* Other options: `$ datawave --help`
* More info: **[view the client script](ansible/roles/dw-client/tasks/files/datawave)**

#### Force Redeploy

Generally speaking, all Anisble tasks here are designed to be idempotent operations on your cluster. Thus, it is usually
safe to assume that executing the *datawave.yml* playbook multiple times will always result in the same cluster state.
However, you may want to change that behavior at times by overriding certain default variables.

For example, you may want to rebuild DataWave and redeploy updated versions of ingest and query services:

```bash
# Force rebuild/redeploy
$ cd datawave-muchos/ansible
$ ansible-playbook -i inventory datawave.yml -e '{ "dw_force_redeploy": true }'

# Or equivalently...
$ scripts/dw-play-redeploy.sh
```
Upon redeploy...

* Previously ingested data in Accumulo is always preserved.
* Any manual, in-place modifications made to deployed services will likely be lost.
* Prior to redeploy, graceful shutdown of DataWave services is attempted.

#### Ansible Tags

For additional flexibility, the *datawave.yml* playbook makes use of Ansible tags, so specific
tasks can be whitelisted/blacklisted via the `--tags`,`--skip-tags` options respectively.
For example:
```bash
# Force a redeploy of DataWave without rebuilding the source code
$ cd datawave-muchos/ansible
$ ansible-playbook -i inventory datawave.yml -e '{ "dw_force_redeploy": true }' --skip-tags build

# Or equivalently...
$ scripts/dw-play-redeploy.sh --skip-tags build
  
# View all tasks and their associated tags for the entire playbook
$ ansible-playbook datawave.yml --list-tasks

# Or equivalently...
$ scripts/dw-play.sh --list-tasks
```

#### Start/Stop Ingest

```bash
cd datawave-muchos/ansible

# Start (this is already a post-deployment task, as dw_start_ingest is set to True by default)
$ ansible-playbook -i inventory start-ingest.yml

# Stop
$ ansible-playbook -i inventory stop-ingest.yml
```
See also [scripts/dw-services-start.sh](scripts/dw-services-start.sh) and [scripts/dw-services-stop.sh](scripts/dw-services-stop.sh)

#### Start/Stop Web Services

```bash
$ cd datawave-muchos/ansible

# Start (can be automated as a post-deployment task, if dw_start_web == True)
$ ansible-playbook -i inventory start-web.yml

# Stop
$ ansible-playbook -i inventory stop-web.yml
```
See also [scripts/dw-services-start.sh](scripts/dw-services-start.sh) and [scripts/dw-services-stop.sh](scripts/dw-services-stop.sh)

## DataWave Ingest Examples

#### TVMAZE Dataset (http://www.tvmaze.com/api)

To download/ingest a small subset of TVMAZE show and cast member data:

```bash
# Note: this can also be automated as a post-deployment task, if dw_ingest_tvmaze == True

$ cd datawave-muchos/ansible
$ ansible-playbook -i inventory tvmaze-ingest.yml
```

To download and ingest *all* TV shows and associated cast info:

```bash
$ cd scripts
$ ./tvmaze-ingest.sh
```
* Script options: `./tvmaze-ingest.sh -h`
* More info: **[ansible/roles/tvmaze/README](ansible/roles/tvmaze/README.md)**
  
#### Wikipedia Dataset (https://dumps.wikimedia.org/enwiki/)

To download a Wikipedia XML data dump and ingest a small subset (~100,000 pages) of its entries:

```bash
# Note: this can also be automated as a post-deployment task, if dw_ingest_wikipedia == True

$ cd datawave-muchos/ansible
$ ansible-playbook -i inventory wikipedia-ingest.yml

# Or equivalently...
$ scripts/wikipedia-ingest.sh
```
* If desired, the entire XML dump may be ingested by tweaking Ansible variable, `wiki_max_streams_to_extract`, subject to
  the storage limitations of your cluster
* More info: **[ansible/roles/wikipedia/README](ansible/roles/wikipedia/README.md)**

[muchos]: https://github.com/apache/fluo-muchos
[muchos-logo]: https://github.com/apache/fluo-muchos/blob/master/contrib/muchos-logo.png
[datawave]: https://github.com/NationalSecurityAgency/datawave
[datawave-logo]: https://github.com/NationalSecurityAgency/datawave/blob/master/datawave-readme.png
[ansible]: https://www.ansible.com/

[li]: http://img.shields.io/badge/license-ASL-blue.svg
[ll]: https://www.apache.org/licenses/LICENSE-2.0
