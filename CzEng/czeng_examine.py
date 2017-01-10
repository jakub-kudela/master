#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time

import scipy.stats as stats


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

def examine_czeng(czeng_file):
	log_major("Examining document ...")

	en_cs_len_ratios = []

	line_index = 0
	for _, _, cs_text, en_text in czeng_file_iter(czeng_file):

		line_index += 1
		log_minor("Examining line %s." % line_index)

		en_len = float(len(en_text))
		cs_len = float(len(cs_text))
		en_cs_len_ratios.append(en_len / cs_len)

	log_major("Document examined.")
	log_major("Logging results.")

	en_cs_len_ratio_mean, en_cs_len_ratio_sd = stats.norm.fit(en_cs_len_ratios)
	log_major("Mean of EN / CS length ratio: %s." % en_cs_len_ratio_mean)
	log_major("Sigma of EN / CS length ratio: %s." % en_cs_len_ratio_sd)

	log_major("Results logged.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-c', '--czeng', required=True, type=str)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	try:
		czeng_file = codecs.open(args.czeng, "r", "utf-8")
		examine_czeng(czeng_file)
		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		czeng_file.close()