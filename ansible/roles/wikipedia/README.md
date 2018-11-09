# DataWave Ingest Example: Wikipedia

## Purpose

The *wikipedia* role and associated playbook *wikipedia-ingest.yml* will leverage your proxy host to perform the following tasks:

1) Download a Wikipedia XML data dump in multistream bz2 format along with its accompanying index file. For example,..
   * enwiki-20180620-pages-articles-multistream.xml.bz2 (~16GB compressed)
   * enwiki-20180620-pages-articles-multistream-index.txt.bz2 (~1GB decompressed)
2) Leverage the byte offset information in the index file to extract a configurable subset of bz2 streams from the data
   file, so that you can adjust the volume of data to be ingested as needed
3) Write extracted bz2 streams to HDFS for DataWave Ingest processing

* Variables defined for the role are described below. See [defaults/main.yml](defaults/main.yml) for default values

## Task Details and Configuration

1) Download Task

   Your proxy host will need ~16GB free in `wiki_dump_local_dir` to store the data file
   and another ~1GB to store the decompressed index file, based on the enwiki 20180620 data dump example

   | Ansible Variable | Purpose |
   |----------|---------|
   | wiki_dump_date | Date in YYYYMMDD format denoting the date that the Wikipedia dump was produced |
   | wiki_dump_lang | Two-letter code denoting the language version. E.g., *en* |
   | wiki_dump_url | Remote source for the data and index files |
   | wiki_dump_local_dir | Local directory on the proxy for storing the downloaded data and index files

   * Overriding the `wiki_dump_date` and `wiki_dump_lang` vars will automatically update the default value of `wiki_dump_url` 
   * The value of `wiki_dump_date` will be used as the DataWave [shard date][data-model] for all ingested documents
  
2) Stream Extraction

   Bz2 streams from the data file are extracted according to the variable definitions below

   | Ansible Variable | Purpose |
   |----------|---------|
   | wiki_stream_offsets_file | File containing a list of byte offsets identifying the bz2 streams to be extracted from the data file. See [below](#leveraging-the-index-file-for-your-own-needs) for details |
   | wiki_max_streams_to_extract | Integer denoting the maximum number of streams to extract from the data file |
   | wiki_stream_extract_dir | Local directory in which to extract bz2 streams. The amount of additional free space needed here will depend on the size of each stream extracted and on the value of `wiki_stream_aggregation` (see step 3 below)|
   
   * Streams will *not* be decompressed. They're written to HDFS immediately after extraction from the data file, and
     they'll be deleted from local storage once written to HDFS
     
   * The default value of `wiki_max_streams_to_extract` is intentionally set low to permit quick ingestion of a small-ish
     subset of the Wikipedia corpus, so you'll need to override it if you wish to process the entire dataset. Note that the
	 enwiki-20180620 data dump is comprised of **185687** total bz2 streams
     
   * By default, `wiki_stream_offsets_file` is created dynamically from the multistream index file, via the
     [prepare-offsets.sh](tasks/files/prepare-offsets.sh) script. To override the default list, just point to your own
     custom offsets file as needed
   
3) Ingest Processing

   Wikipedia ingest processing should already be preconfigured in your DataWave deployment, so all that's required is that
   you have DataWave Ingest running and that you write the compressed wiki XML to the configured HDFS input directory.
   
   The following variables are used to control how/where files are written in HDFS
 
   | Ansible Variable | Purpose |
   |----------|---------|
   | wiki_stream_aggregation | Integer denoting the number of bz2 streams to combine into a single file before flushing to HDFS. Override as needed to increase/decrease the size of files written to HDFS, i.e., in order to fine tune the size of inputs to the map tasks of your ingest jobs |
   | wiki_hdfs_ingest_input_dir | HDFS staging directory for raw Wikipedia XML files, as preconfigured for DataWave Ingest |
   
   * Note that we could also just drop the entire bz2 data dump directly into `wiki_hdfs_ingest_input_dir` for processing,
     but doing so could easily overwhelm your cluster, particularly if FlagMaker and other Mapreduce-related configs are not
	 optimized for that use case
	 
   * In any case, if you do intend to ingest the entire Wikipedia corpus, you'll likely need to fine tune ingest-related
     configs for your cluster in order for performance to be optimal
   
## Leveraging the Index File for Your Own Needs

You may want to leverage the information in the index file to increase/decrease the number of bz2 streams extracted
or to target specific ranges of streams in the corpus. The examples below provide guidance on how to leverage the
index for this purpose.

* When the index file is decompressed, you'll note that its schema is as follows:
  
  ```
  <Byte Offset for the Wikipedia Page's Parent Bz2 Stream>:<Wikipedia Page ID>:<Wikipedia Page Title>
  
  ```

  For example:
  ```bash
   $ cat enwiki-20180620-pages-articles-multistream-index.txt | head -n 101
   616:10:AccessibleComputing
   616:12:Anarchism
   616:13:AfghanistanHistory
   616:14:AfghanistanGeography
   616:18:AfghanistanCommunications
   616:23:AssistiveTechnology
   ...
   ...
   616:589:Ashmore And Cartier Islands
   616:590:Austin (disambiguation)
   616:593:Animation
   616:594:Apollo
   616:595:Andre Agassi
   627987:596:Artificial languages   # 101st Wikipedia page == new byte offset, and so on...
 
  ```
  * All bz2 streams in the dump (except for the last stream) are guaranteed to contain 100 articles each

* The total number of Wikipedia articles contained in the dump file is determined by simply counting the number of
  lines in the index.

  ```bash
   $ cat enwiki-20180620-pages-articles-multistream-index.txt | wc -l
   18568656
  ```

* So, how do I ingest the entire Wikipedia data dump?

  The total number of streams within the dump can be easily calculated by counting the distinct offsets
  in the index
  
  ```bash
   $ cat enwiki-20180620-pages-articles-multistream-index.txt | cut -d':' -f1 | uniq | wc -l
   185687
  ```
  If you want to ingest the entire Wikipedia corpus, you'd use the output of the command above for `wiki_max_streams_to_extract`

  * Note that the last bz2 stream in the data file always extends from the index's final offset to EOF in the data file

* How do I generate the full list of distinct offsets for any given Wikipedia dump?

  ```bash
   $ cat enwiki-YYYYMMDD-pages-articles-multistream-index.txt | cut -d':' -f1 | uniq > ~/enwiki-YYYYMMDD-offsets.txt
   
   # Append the ending byte offset (EOF) for the final stream, denoted by the dump's total size in bytes...

   $ echo "$(stat --printf="%s" enwiki-YYYYMMDD-pages-articles-multistream.xml.bz2)" >> ~/enwiki-YYYYMMDD-offsets.txt
  ```
  * **Note**: the *process-wikidump.sh* script always counts two adjacent byte offsets as 1 stream. Keep that
    in mind when creating a custom offsets file, as it relates to both your `wiki_max_streams_to_extract` and
	`wiki_stream_aggregation` settings

## Notable Scripts

* The [prepare-offsets.sh](tasks/files/prepare-offsets.sh) script is used to generate the list of offsets for stream
  extraction. If you're only interested in a particular subset of bz2 streams from the dump, then modify this script to
  generate a custom offset list
  
* The [process-wikidump.sh](tasks/files/process-wikidump.sh) script performs all the stream extraction and HDFS-write work,
  and it can be used together with *prepare-offsets.sh* to perform steps 2 and 3 above independently from Ansible, if desired

[data-model]: https://code.nsa.gov/datawave/docs/latest/getting-started/data-model#primary-data-table
