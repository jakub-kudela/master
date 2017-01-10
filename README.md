# Master's Thesis: Mining Parallel Corpora from the Web

Click to edit education descriptionIn master's thesis I have focused on the NLP task of mining parallel corpora from the Web. The work is based on the bilingual extension of the **word2vec** model—**bivec** and the **locality-sensitive hashing**.

## Content

`Thesis/` - the thesis in PDF format and its zipped \LaTeX\ source code;  
`Output/` - the acquired parallel corpus and the experiments' results;  
`CommonCrawl/` - utilities for processing of the CommonCrawl dataset;  
`CzEng/` - utilities for processing of the CzEng 1.0 dataset;  
`Tools/` - tools and resources required by the method;  
`Align/` - set of scripts implementing the method;  

`Output/cc_token_class_dump` - the acquired cs-en corpus from the Common Crawl dataset;  
`Output/cc_eval_500_paragraphs` - evaluations of the 500 randomly selected paragraph pairs;  
`Output/cc_eval_www_csa_cz` - evaluations of alignments for the www.csa.cz website. 

## How to replicate the first experiment using the CzEng 1.0 dataset

1. We need to install all the prerequisities for the first part of the training. Make sure you are familiar with the linceses for all the tools used by the method. Let us refer to the root of this distribution as `$DIST`. So this file is `$DIST/README.txt`. Please, follow the instructions very carefully, every name of every single file matters.

	```
	mkdir $DIST/Tools
	```

2. Install MorphoDiTa:

	```
	cd $DIST/Tools
	wget https://github.com/ufal/morphodita/releases/download/v1.3.0/morphodita-1.3.0-bin.zip
	unzip morphodita-1.3.0-bin.zip
	rm morphodita-1.3.0-bin.zip
	mv morphodita-1.3.0-bin morphodita
	cd morphodita/src
	make
	```

3. Obtain MorphoDiTa models:

	```
	cd $DIST/Tools
	mkdir morphodita_models
	wget https://lindat.mff.cuni.cz/repository/xmlui/bitstream/handle/11858/00-097C-0000-0023-68D8-1/czech-morfflex-pdt-131112.zip
	unzip czech-morfflex-pdt-131112.zip
	rm czech-morfflex-pdt-131112.zip
	mv czech-morfflex-pdt-131112 morphodita_models
	wget https://lindat.mff.cuni.cz/repository/xmlui/bitstream/handle/11858/00-097C-0000-0023-68D9-0/english-morphium-wsj-140407.zip
	unzip english-morphium-wsj-140407.zip
	rm english-morphium-wsj-140407.zip
	mv english-morphium-wsj-140407 morphodita_models
	```

4. Install SyMGIZA++:

	```
	cd $DIST/Tools
	wget https://github.com/emjotde/symgiza-pp/archive/master.zip
	unzip master.zip
	rm master.zip
	mv symgiza-pp-master symgiza-pp
	wget http://sourceforge.net/projects/boost/files/boost/1.60.0/boost_1_60_0.zip
	unzip boost_1_60_0.zip
	rm boost_1_60_0.zip
	cp -r boost_1_60_0/boost symgiza-pp
	rm -r boost_1_60_0
	cd symgiza-pp
	./configure
	make
	```

5. Install bivec:

	```
	cd $DIST/Tools/bivec
	make
	```

	The implementation of bivec has a bug in the bivec.c file within the method 
	`TrainModel()`. It does not save vectors for the target language if evaluation is on.
	The provided distribution is slightly modified. It contains fixes to this problem.

6. Install Python, if not installed already (We have used Python 2.7.11). Along with Python, the method also requires the following Python packages:

	```
	sudo pip install numpy
	sudo pip install annoy
	sudo pip install pybrain
	```

7. Execute the first part of the training of our method on CzEng 1.0. Make sure you know your CzEng 1.0 registration username: `$CZENG_USERNAME`. In case you are not registered: https://ufal.mff.cuni.cz/czeng/czeng10/.

	```
	mkdir $DIST/CzEngData
	cd $DIST/CzEngData
	nohup ../CzEng/czeng_pipeline.sh -d -t -l -s -c -g -b <<< $CZENG_USERNAME > czeng_pipeline.log 2>&1 &!
	watch -n 2 tail -40 czeng_pipeline.log
	```

	This script downloads, tokenizes, lemmatizes, splits and cleans CzEng 1.0 and runs SyMGIZA++ and bivec on the head. The execution can last up to 2-3 days and it creates a lot of output files. The important files are as follows:

	`$DIST/CzEngData/czeng_token_head_giza/all.param` - dictionary created for the tokenized head;
	`$DIST/CzEngData/czeng_lemma_head_giza/all.param` - dictionary created for the lemmatized head;
	`$DIST/CzEngData/czeng_token_head_bivec/wordvec.cs` - vectors for the Czech words for the tokenized head;
	`$DIST/CzEngData/czeng_token_head_bivec/wordvec.en` - vectors for the English words for the tokenized head;
	`$DIST/CzEngData/czeng_lemma_head_bivec/wordvec.cs` - vectors for the Czech words for the lemmatized head;
	`$DIST/CzEngData/czeng_lemma_head_bivec/wordvec.en` - vectors for the English words for the lemmatized head.

8. As a next step, execute the second part of the training on the head and the running process on the tail.

	```
	mkdir $DIST/AlignData
	cd $DIST/AlignData
	nohup ../Align/align_pipeline.sh -czt -czl > align_pipeline.cz.log 2>&1 &!
	watch -n 2 tail -40 align_pipeline.cz.log
	```

	This process can take up to another 2-3 days, depending on the configuration of the PC. Similarly, this script produces a lot of files, the most important are summarized below:

	`$DIST/AlignData/*_bench` - show how many parallel documents ended up on the k-th best place;
	`$DIST/AlignData/*_classifier` - files with the configurations of the trained classifiers;
	`$DIST/AlignData/*_class_dump` - contain resulting alignments in a file with the format:

	```
	<bin_id> <cs_document_id> <en_document_id> <classifier_confidence>
	<cs_sentence>
	<en_sentence_output_alignment>
	<en_sentence_ideal_alignment>
	---empty line---
	...
	```

## How to replicate the second experiment using the July 2015 Common Crawl

1. The output of the first experiment is required at its place. The second experiment uses the trained artifacts from the first one. Make sure you have a Hadoop cluster with at least 30 TB of space for the dataset.

2. Download the July 2015 Common Crawl dataset into the Hadoop cluster:

	```
	mkdir $DIST/CommonCrawlData
	cd $DIST/CommonCrawlData
	hadoop fs -mkdir cc_2015_32
	nohup ../CommonCrawl/cc_download.sh -d cc_2015_32 > cc_download.log 2>&1 &!
	watch -n 2 tail -40 cc_download.log
	```

	This step can last up to 20 days. In case the script is interrupted by anything, re-run the script. It is able to continue in the downloading process. It does not download files already present.

3. Compile the jar file for the WarcTextExtractor:

	```
	cd $DIST/CommonCrawl/WarcTextExtractor
	mvn install
	```

	The implementation internaly uses the optimaize/language-detector Java library. However, the original library used to throw some unexpected exceptions. This issue has been solved by fixing the source code of few of the original classes. The edited code is located in the langdetect package.

4. Run the first MapReduce job filtering cs-en web domains:

	```
	cd $DIST/CommonCrawlData
	nohup hadoop jar ../CommonCrawl/WarcTextExtractor/target/WarcTextExtractor-0.0.1.jar \
	    --stage_set domains --warcs_path cc_2015_32 --domains_path cc_domains \
	    > WarcTextExtractor.domains.log 2>&1 &!
	watch -n 2 tail -40 WarcTextExtractor.domains.log
	```

	This process can take up to 1 day, depending on the configuration of the Hadoop cluster.

5. Filter the cs-en web domains, as is described in the thesis:

	```
	cd $DIST/CommonCrawlData
	hadoop fs -cat cc_domains/* > cc_domains
	hadoop fs -rm -r cc_domains
	cat cc_domains | awk '($3 / $5) > 0.01 && ($5 / $3) > 0.01' > cc_domains_filtered
	hadoop fs -copyFromLocal cc_domains_filtered cc_domains_filtered
	```

6. Run the second MapReduce job filtering cs-en paragraphs:

	```
	cd $DIST/CommonCrawlData
	nohup hadoop jar ../CommonCrawl/WarcTextExtractor/target/WarcTextExtractor-0.0.1.jar \
	    --stage_set texts --warcs_path cc_2015_32_ --domains_path cc_domains_filtered --texts_path cc_texts \
	    > WarcTextExtractor.texts.log 2>&1 &!
	watch -n 2 tail -40 WarcTextExtractor.texts.log
	```

	Also, this process can take up to 1 day.

7. Tokenize and lemmatize the refined paragraphs:

	```
	cd $DIST/CommonCrawlData
	hadoop fs -cat cc_texts/* > cc
	hadoop fs -rm -r cc_texts
	nohup ../CommonCrawl/cc_pipeline.sh -t -l > cc_pipeline.log 2>&1 &!
	watch -n 2 tail -40 cc_pipeline.log
	```

	The preprocessing can take up to 6 hours.

8. Run the method to align the refined paragraphs:

	```
	cd $DIST/AlignData
	nohup ../Align/align_pipeline.sh -cct -ccl > align_pipeline.cc.log 2>&1 &!
	watch -n 2 tail -40 align_pipeline.cc.log
	```

	This can take up to 1 day and it produces a lot of files, the most important is the `$DIST/AlignData/cc_token_class_dump`. It stores the resulting parallel corpus with the format:

	```
	<domain> <cs_document_id> <en_document_id> <classifier_confidence>
	<cs_paragraph>
	<en_paragraph>
	---empty line---
	...
	```
