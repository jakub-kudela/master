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

def filter_align(align_file, threshold, output_file):
	log_major("Filtering bins ...")

	align_index = 0
	for align_bin, aligns in align_file_bin_iter(align_file):

		log_major("Filtering bin '%s' ..." % align_bin)

		for src_doc_id, src_aligns in aligns.items():

			align_index += 1
			log_minor("Filtering alignment %s." % align_index)

			src_aligns.sort(key=operator.itemgetter(1), reverse=True)

			for trg_doc_id, score in src_aligns:

				if score > threshold:
					output_row = "\t".join(map(str, (align_bin, src_doc_id, trg_doc_id, score)))
					output_file.write("%s\n" % output_row)

		log_major("Bin '%s' filtered." % align_bin)

		align_item, trg_item = None, None

	log_major("All bins filtered.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-a', '--align', required=True, type=str)
	parser.add_argument('-t', '--threshold', type=float, default=1.0)
	parser.add_argument('-o', '--output', required=True, type=str)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	align_file = codecs.open(args.align, "r", "utf-8")
	output_file = codecs.open(args.output, "w", "utf-8")

	try:
		filter_align(align_file, args.threshold, output_file)
		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		align_file.close()
		output_file.close()
