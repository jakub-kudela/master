#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time


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

def czeng_file_iter(czeng_file):
	for line in czeng_file:
		
		tokens = line.strip().split("\t")

		id_ = tokens[0]
		probab = float(tokens[1])
		cs_text = tokens[2]
		en_text = tokens[3]

		yield((id_, probab, cs_text, en_text))

def dice_czeng(czeng_file, output_file, threshold):
	log_major("Examining document ...")

	coocs, cs_occus, en_occus = {}, {}, {}

	line_index = 0
	for _, _, cs_text, en_text in czeng_file_iter(czeng_file):

		line_index += 1
		log_minor("Examining line %s." % line_index)

		cs_words = set(cs_text.split())
		en_words = set(en_text.split())

		for cs_word in cs_words:
			cs_occus[cs_word] = cs_occus.get(cs_word, 0) + 1

		for en_word in en_words:
			en_occus[en_word] = en_occus.get(en_word, 0) + 1

		for cs_word in cs_words:
			cs_word_coocs = coocs.get(cs_word, {})
			coocs[cs_word] = cs_word_coocs

			for en_word in en_words:
				cs_word_coocs[en_word] = cs_word_coocs.get(en_word, 0) + 1

	log_major("Document examined.")
	log_major("Outputting results.")

	for cs_word, cs_word_coocs in coocs.items():
		cs_word_occu = cs_occus.get(cs_word, 0)

		for en_word, cooc in cs_word_coocs.items():
			en_word_occu = en_occus.get(en_word, 0)
			dice = (2. * cooc) / (cs_word_occu + en_word_occu)

			if dice > threshold:
				output_file.write("%s\t%s\t%s\n" % (cs_word, en_word, dice))

	log_major("Results outputted.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-c', '--czeng', required=True, type=str)
	parser.add_argument('-o', '--output', required=True, type=str)
	parser.add_argument('-t', '--threshold', type=float, default=0.1)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	czeng_file = codecs.open(args.czeng, "r", "utf-8")
	output_file = codecs.open(args.output, "w", "utf-8")

	try:
		dice_czeng(czeng_file, output_file, args.threshold)
		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		czeng_file.close()
		output_file.close()
