#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time
import operator


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

def doc_file_bin_iter(doc_file):
	bin_, docs = None, None

	for line in doc_file:
		
		tokens = line.strip().split("\t")

		doc_bin = tokens[0]
		doc_id = tokens[1]
		doc_text = tokens[2]

		if doc_bin != bin_:
			if bin_: yield (bin_, docs)
			bin_, docs = doc_bin, {}

		docs[doc_id] = doc_text

	if bin_: yield (bin_, docs)

def align_file_bin_iter(align_file):
	bin_, aligns = None, None

	for line in align_file:
		
		tokens = line.strip().split("\t")

		align_bin = tokens[0]
		src_doc_id = tokens[1]
		trg_doc_id = tokens[2]
		score = float(tokens[3])

		if align_bin != bin_:
			if bin_: yield (bin_, aligns)
			bin_, aligns = align_bin, {}
		
		src_aligns = aligns.get(src_doc_id, [])
		src_aligns.append((trg_doc_id, score))
		aligns[src_doc_id] = src_aligns

	if bin_: yield (bin_, aligns)

def bench_align(align_file, trg_doc_file, output_file):
	log_major("Benchmarking bins ...")

	align_bin_iter = align_file_bin_iter(align_file)
	trg_bin_iter = doc_file_bin_iter(trg_doc_file)
	align_item, trg_item = None, None

	mindex_freqs = {}

	align_index = 0
	while True:

		if not align_item: align_item = next(align_bin_iter, None)
		if not trg_item: trg_item = next(trg_bin_iter, None)
		if not align_item or not trg_item: break

		align_bin, aligns = align_item
		trg_bin, trg_docs = trg_item

		if align_bin < trg_bin: align_bin = None
		if trg_bin < align_bin: trg_bin = None
		if align_bin != trg_bin: continue

		log_major("Benchmarking bin '%s' ..." % align_bin)

		for src_doc_id, src_aligns in aligns.items():

			align_index += 1
			log_minor("Benchmarking alignment %s." % align_index)

			src_aligns.sort(key=operator.itemgetter(1), reverse=True)
			corr_doc_text = trg_docs[src_doc_id]
			corr_doc_hash = hash(corr_doc_text)

			mindex = None
			for index in range(len(src_aligns)):

				trg_doc_id = src_aligns[index][0]
				trg_doc_text = trg_docs[trg_doc_id]
				trg_doc_hash = hash(trg_doc_text)

				if trg_doc_hash == corr_doc_hash:
					mindex = index
					break

			mindex_freqs[mindex] = mindex_freqs.get(mindex, 0) + 1

		log_major("Bin '%s' benchmarked." % align_bin)

		align_item, trg_item = None, None

	log_major("All bins benchmarked.")
	log_major("Outputting results ...")

	for mindex, mindex_freq in mindex_freqs.items():

		output_row = "\t".join(map(str, (mindex, mindex_freq)))
		output_file.write("%s\n" % output_row)

	log_major("Results outputted.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-a', '--align', required=True, type=str)
	parser.add_argument('-t', '--trg_doc', required=True, type=str)
	parser.add_argument('-o', '--output', required=True, type=str)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	align_file = codecs.open(args.align, "r", "utf-8")
	trg_doc_file = codecs.open(args.trg_doc, "r", "utf-8")
	output_file = codecs.open(args.output, "w", "utf-8")

	try:
		bench_align(align_file, trg_doc_file, output_file)
		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		align_file.close()
		trg_doc_file.close()
		output_file.close()
