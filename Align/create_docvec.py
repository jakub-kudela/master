#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time
import math


logger_freq = 2
logger_timestamp = time.time()
logger = logging.getLogger(__file__)

def log_major(message):
	global logger_timestamp
	
	logger.info(message)
	logger_timestamp = time.time()
	
def log_minor(message, major=True):
	global logger_timestamp

	since_last = time.time() - logger_timestamp
	if since_last < logger_freq: return

	logger.info(message)
	logger_timestamp = time.time()

def wordvec_file_iter(wordvec_file):
	# Skipping header line.
	line = wordvec_file.readline()

	for line in wordvec_file:
		
		tokens = line.strip().split()

		word = tokens[0]
		wordvec = map(float, tokens[1:])

		yield((word, wordvec))

def doc_file_bin_iter(doc_file):
	bin_, docs = None, None

	for line in doc_file:
		
		tokens = line.strip().split("\t")

		doc_bin = tokens[0]
		doc_id = tokens[1]
		doc_text = tokens[2]

		if doc_bin != bin_:
			if bin_: yield (bin_, docs)
			bin_, docs = doc_bin, []
			
		docs.append((doc_id, doc_text))

	if bin_: yield(bin_, docs)

def create_docvec(doc_file, wordvec_file, output_file):
	# WARNING: Wordvec normalization decreases precision!
	# Normalization seems like a good idea but it is not.

	log_major("Loading wordvecs ...")

	wordvecs = {}

	wordvec_index = 0
	for word, wordvec in wordvec_file_iter(wordvec_file):

		wordvec_index += 1
		log_minor("Loading wordvec %s." % wordvec_index)

		wordvecs[word] = wordvec

	log_major("Wordvecs loaded.")
	log_major("Processing bins ...")
	
	doc_index = 0
	for bin_, docs in doc_file_bin_iter(doc_file):
		
		log_major("Processing bin '%s' ..." % bin_)
		log_major("Removing duplicates ...")

		docs_unique = []
		docs_hashes = set()
		for doc_id, doc_text in docs:

			doc_hash = hash(doc_text)
			if doc_hash in docs_hashes: continue

			docs_unique.append((doc_id, doc_text))
			docs_hashes.add(doc_hash)

		docs = docs_unique

		log_major("Duplicates removed.")
		log_major("Processing Tf-idf model ...")

		freqs = {}
		for _, doc_text in docs:

			doc_words = doc_text.split()
			for word in set(doc_words):

				freqs[word] = freqs.get(word, 0) + 1

		idfs = {}
		for word, freq in freqs.items():
			idfs[word] = math.log(len(docs) / float(freq), 10)

		log_major("Tf-idf model processed.")
		log_major("Processing documents ...")

		for doc_id, doc_text in docs:

			doc_index += 1
			log_minor("Processing document %s." % doc_index)

			doc_words = doc_text.split()

			tfs = {}
			for word in doc_words:
				tfs[word] = tfs.get(word, 0) + 1

			tfidfs = {}
			for word in set(doc_words):
				tfidfs[word] = tfs[word] * idfs[word]

			docvec = None
			for word, tfidf in tfidfs.items():

				wordvec = wordvecs.get(word)
				if not wordvec: continue

				if not docvec: docvec = [0] * len(wordvec)
				tfidfs_wordvec = [x * tfidf for x in wordvec]
				docvec = [sum(x) for x in zip(docvec, tfidfs_wordvec)]

			if docvec:
				docvec_str = " ".join(map(str, docvec))
				output_row = "\t".join(map(str, (bin_, doc_id, docvec_str)))
				output_file.write("%s\n" % output_row)

		log_major("Documents processed.")
		log_major("Bin '%s' processed." % bin_)

	log_major("All bins processed.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-d', '--doc', required=True, type=str)
	parser.add_argument('-w', '--wordvec', required=True, type=str)
	parser.add_argument('-o', '--output', required=True, type=str)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	doc_file = codecs.open(args.doc, "r", "utf-8")
	wordvec_file = codecs.open(args.wordvec, "r", "utf-8")
	output_file = codecs.open(args.output, "w", "utf-8")

	try:
		create_docvec(doc_file, wordvec_file, output_file)
		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		doc_file.close()
		wordvec_file.close()
		output_file.close()
