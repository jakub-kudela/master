#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time

from annoy import AnnoyIndex


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

def docvec_file_bin_iter(doc_file):
	bin_, docvecs = None, None

	for line in doc_file:
		
		tokens = line.strip().split("\t")

		doc_bin = tokens[0]
		doc_id = tokens[1]
		docvec_str = tokens[2].split()
		docvec = map(float,docvec_str)

		if doc_bin != bin_:
			if bin_: yield (bin_, docvecs)
			bin_, docvecs = doc_bin, []
			
		docvecs.append((doc_id, docvec))

	if bin_: yield (bin_, docvecs)

def align_docvec(src_docvec_file, trg_docvec_file, ann, n_trees, search_k, output_file):
	# Annoy homepage and API documentation.
	# https://github.com/spotify/annoy#full-python-api

	# Tradeoff choosing settings for the search_k.
	# https://github.com/spotify/annoy#tradeoffs
	if not search_k: search_k = ann * n_trees * 2

	log_major("Aligning bins ...")

	src_bin_iter = docvec_file_bin_iter(src_docvec_file)
	trg_bin_iter = docvec_file_bin_iter(trg_docvec_file)
	src_item, trg_item = None, None 

	src_docvec_index = 0
	while True:

		if not src_item: src_item = next(src_bin_iter, None)
		if not trg_item: trg_item = next(trg_bin_iter, None)
		if not src_item or not trg_item: break

		src_bin, src_docvecs = src_item
		trg_bin, trg_docvecs = trg_item

		if src_bin < trg_bin: src_item = None
		if trg_bin < src_bin: trg_item = None
		if src_bin != trg_bin: continue

		log_major("Aligning bin '%s' ..." % src_bin)
		log_major("Collecting target docvecs ...")

		docvec_length = len(trg_docvecs[0][1])
		annoy = AnnoyIndex(docvec_length, metric='angular')

		# Annoy assumes that items are indexed from 0 to (n-1).
		# https://github.com/spotify/annoy#python-code-example
		
		new_trg_doc_id = 0
		trg_doc_id_map = {}
		for trg_doc_id, trg_docvec in trg_docvecs:

			trg_doc_id_map[new_trg_doc_id] = trg_doc_id
			annoy.add_item(new_trg_doc_id, trg_docvec)
			new_trg_doc_id += 1

		log_major("Target docvecs collected.")
		log_major("Indexing target docvecs ...")

		annoy.build(n_trees)

		log_major("Target docvecs indexed.")
		log_major("Querying source docvecs ...")

		for src_doc_id, src_docvec in src_docvecs:

			src_docvec_index += 1
			log_minor("Querying source docvec %s." % src_docvec_index)

			trg_neighbours = annoy.get_nns_by_vector(src_docvec, 
				ann, search_k=search_k, include_distances=True)

			trg_doc_ids = [trg_doc_id_map[x] for x in trg_neighbours[0]]
			cosine_sims = [(1 - (x / 2.)) for x in trg_neighbours[1]]

			for trg_doc_id, cosine_sim in zip(trg_doc_ids, cosine_sims):
				
				output_row = "\t".join(map(str, (src_bin, src_doc_id, trg_doc_id, cosine_sim)))
				output_file.write("%s\n" % output_row)

		log_major("Source docvecs queried.")
		log_major("Bin '%s' aligned." % src_bin)

		src_item, trg_item = None, None

	log_major("All bins aligned.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-s', '--src_docvec', required=True, type=str)
	parser.add_argument('-t', '--trg_docvec', required=True, type=str)
	parser.add_argument('-n', '--ann', type=int, default=10)
	parser.add_argument('-nt', '--n_trees', type=int, default=500)
	parser.add_argument('-sk', '--search_k', type=int, default=None)
	parser.add_argument('-o', '--output', required=True, type=str)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	src_docvec_file = codecs.open(args.src_docvec, "r", "utf-8")
	trg_docvec_file = codecs.open(args.trg_docvec, "r", "utf-8")
	output_file = codecs.open(args.output, "w", "utf-8")

	try:
		align_docvec(src_docvec_file, trg_docvec_file, 
			args.ann, args.n_trees, args.search_k, output_file)

		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		src_docvec_file.close()
		trg_docvec_file.close()
		output_file.close()
