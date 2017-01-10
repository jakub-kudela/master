#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time
import math
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

def param_file_iter(param_file):
	for line in param_file:

		tokens = line.strip().split()
		
		src_word = tokens[0]
		trg_word = tokens[1]
		param = float(tokens[2])

		yield((src_word, trg_word, param))

def vcb_param_file_iter(param_file):
	for line in param_file:

		tokens = line.strip().split()
		
		src_word_id = int(tokens[0])
		trg_word_id = int(tokens[1])
		param = float(tokens[2])

		yield((src_word_id, trg_word_id, param))

def vcb_file_iter(vcb_file):
	for line in vcb_file:

		tokens = line.strip().split()
		
		word_id = int(tokens[0])
		word = tokens[1]
		count = int(tokens[2])

		yield((word_id, word, count))

def harmonic_mean(param_one, param_two):
	# Combined param is calculated by harmonic mean.
	# https://en.wikipedia.org/wiki/Harmonic_mean
	return 2. / ((1. / param_one) + (1. / param_two))

# Merging param files containing direct words, not words IDs referencing vocbulary file.
def merge_param(fwd_param_file, rev_param_file, log_param, min_param, output_file):
	log_major("Loading forward params ...")

	src_trg_params = {}

	param_index = 0
	for src_word, trg_word, src_trg_param in param_file_iter(fwd_param_file):

		param_index += 1
		log_minor("Loading param %s." % param_index)

		src_trg_params[(src_word, trg_word)] = src_trg_param

	log_major("Forward params loaded.")
	log_major("Merging reverse params ...")

	param_index = 0
	for trg_word, src_word, trg_src_param in param_file_iter(rev_param_file):

		param_index += 1
		log_minor("Merging reverse param %s." % param_index)

		src_trg_param = src_trg_params.get((src_word, trg_word), None)
		if not src_trg_param: continue

		if log_param: src_trg_param = math.exp(src_trg_param)
		if log_param: trg_src_param = math.exp(trg_src_param)
		
		mean_param = harmonic_mean(src_trg_param, trg_src_param)
		if mean_param < min_param: continue

		output_file.write("%s\t%s\t%s\n" % (trg_word, src_word, mean_param))

	log_major("Reverse params merged.")

# Merging param files containing words IDs referencing vocbulary file, not direct words.
def merge_param_vcb(src_vcb_file, trg_vcb_file, fwd_param_file, rev_param_file, log_param, min_param, output_file):
	log_major("Loading source vocbulary ...")

	src_vcb = {}

	word_index = 0
	for word_id, word, _ in vcb_file_iter(src_vcb_file):

		word_index += 1
		log_minor("Loading word %s." % word_index)

		src_vcb[word_id] = word

	log_major("Source vocbulary loaded.")
	log_major("Loading target vocbulary ...")

	trg_vcb = {}

	word_index = 0
	for word_id, word, _ in vcb_file_iter(trg_vcb_file):

		word_index += 1
		log_minor("Loading word %s." % word_index)

		trg_vcb[word_id] = word

	log_major("Source vocbulary loaded.")
	log_major("Loading forward params ...")

	src_trg_params = {}

	param_index = 0
	for src_word_id, trg_word_id, src_trg_param in vcb_param_file_iter(fwd_param_file):

		param_index += 1
		log_minor("Loading param %s." % param_index)

		src_trg_params[(src_word_id, trg_word_id)] = src_trg_param

	log_major("Forward parameters loaded.")	
	log_major("Merging reverse params ...")

	param_index = 0
	for trg_word_id, src_word_id, trg_src_param in vcb_param_file_iter(rev_param_file):

		param_index += 1
		log_minor("Merging reverse param %s." % param_index)

		src_trg_param = src_trg_params.get((src_word_id, trg_word_id), None)
		if not src_trg_param: continue

		mean_param = harmonic_mean(src_trg_param, trg_src_param)
		if mean_param < min_param: continue

		src_word, trg_word = src_vcb[src_word_id], trg_vcb[trg_word_id]
		output_file.write("%s\t%s\t%s\n" % (trg_word, src_word, mean_param))

	log_major("Reverse params merged.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-s', '--src_vcb', type=str)
	parser.add_argument('-t', '--trg_vcb', type=str)
	parser.add_argument('-f', '--fwd_param', required=True, type=str)
	parser.add_argument('-r', '--rev_param', required=True, type=str)
	parser.add_argument('-l', '--log_param', action='store_true', default=False)
	parser.add_argument('-m', '--min_param', type=float, default=0)
	parser.add_argument('-o', '--output', required=True, type=str)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	with_vcb = args.src_vcb and args.trg_vcb
	src_vcb_file = codecs.open(args.src_vcb, "r", "utf-8") if with_vcb else None
	trg_vcb_file = codecs.open(args.trg_vcb, "r", "utf-8") if with_vcb else None
	
	fwd_param_file = codecs.open(args.fwd_param, "r", "utf-8")
	rev_param_file = codecs.open(args.rev_param, "r", "utf-8")
	output_file = codecs.open(args.output, "w", "utf-8")

	try:
		if not with_vcb:
			merge_param(fwd_param_file, rev_param_file, 
				args.log_param, args.min_param, output_file)
		else:
			merge_param_vcb(src_vcb_file, trg_vcb_file, fwd_param_file, 
				rev_param_file, args.log_param, args.min_param, output_file)

		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		if with_vcb:
			src_vcb_file.close()
			trg_vcb_file.close()

		fwd_param_file.close()
		rev_param_file.close()
		output_file.close()
