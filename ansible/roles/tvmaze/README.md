# DataWave Ingest Example: TVMAZE DB

## Purpose

The goal of this example is to allow you to download and ingest as much or as little of the
[TVMAZE](http://tvmaze.com/api) database as you wish, taking advantage of your Ansible *tvmaze*
inventory group to spread the download and HDFS-write work evenly across its hosts.

## TVMAZE API Notes

At the time of this writing, the entire TVMAZE db consists of only around 37000 TV shows and the
total data volume is relatively small. However, retrieving all show and cast member metadata can be
very time consuming due to the following:

* Shows must be retrieved one at a time
* The API service caps the number of requests from a single IP address over a given time interval:
  *["to allow at least 20 calls every 10 seconds, per IP address"](http://www.tvmaze.com/api#rate-limiting)*

If your cluster hosts have distinct public IPs assigned, then your overall ingest throughput should be very
good, increasing as the number of tasked hosts increases. If all your hosts happen to share the same outside IP,
it can take several hours to complete ingestion of the entire corpus, regardless of how many hosts are tasked.

#### TV Show Lookups

The **api.tvmaze.com/shows/\<ID\>?embed=cast** endpoint is used to fetch each show and its associated
cast members. Show ID's start at 1 in the TVMAZE database, and at the time of this writing the highest
known ID is 37199.

## Ansible Playbook for DataWave Ingest

The [tvmaze-ingest.yml](../../tvmaze-ingest.yml) playbook is designed to retrieve a discrete range of TV
shows via lookup on their integer ID's as described above. Shows are fetched in ascending sequential order,
and the range of shows to be downloaded by the given play is configurable via the following variables:

| Ansible Variable | Purpose |
|----------|---------|
| tvmz_starting_show_id | Integer TVMAZE ID to start downloads (inclusive) |
| tvmz_max_show_id | Integer TVMAZE ID to stop downloads (inclusive) |
| tvmz_max_shows_per_host | Integer limiting the number of shows downloaded during a given play per targeted worker. Workers will stop downloading once this threshold is reached, regardless of whether or not `tvmz_max_show_id` is reached |
| tvmz_download_local_dir | Local directory on targeted hosts for writing shows to file

* Generally, the total shows downloaded across all hosts in a single play will be
  `tvmz_max_shows_per_host * <number of hosts>`, unless `tvmz_max_show_id` is reached first. Note that the
  default value for `tvmz_max_shows_per_host` is intentionally set low in order to decrease DataWave Ingest
  latency and decrease the time it takes to enable queries via DataWave Web.

  See [defaults/main.yml](defaults/main.yml) to see all default values.

Lastly, show ID's can be sparsely populated in the TVMAZE db, so Ansible tasks are designed to deal gracefully
with ID's that don't exist (*404* response), as well as with 'rate-limit-exceeded' warnings (*429* response), etc.

## Use `tvmaze-ingest.sh` to Ingest the Entire Corpus

For convenience, the [tvmaze-ingest.sh](../../../scripts/tvmaze-ingest.sh) bash script provides a wrapper for the
*tvmaze-ingest.yml* playbook and will make it easier for you to ingest the entire TVMAZE corpus, if desired. Script
parameters allow you to split the work over multiple plays and to tune ingest latency however you want.

Compared to the Wikipedia corpus, TVMAZE data volume is negligible. So, it's unlikely that it will put significant
pressure on local and distributed storage, even if the entire corpus is downloaded and you only have a few nodes
in your cluster
