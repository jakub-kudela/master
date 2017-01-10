#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time
import tempfile
import shutil
import re


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

def czeng_clean(czeng_file, czeng_path, min_tokens, max_tokens):
	# The tempfile.NamedTemporaryFile method helps to find the right name for the temporary file.
	temp_file = tempfile.NamedTemporaryFile(prefix='czeng_clean.py_', dir=os.getcwd(), delete=True)
	temp_path = temp_file.name
	temp_file.close()

	log_major("Cleaning document ...")

	temp_file = codecs.open(temp_path, "w", "utf-8")

	word_regex = re.compile(r'\b[^\W\d_]+\b', re.UNICODE)
	no_letter_regex = re.compile(r'^[\W\d_]*$', re.UNICODE)

	too_few_token_entries = 0
	too_many_token_entries = 0
	no_letter_text_entries = 0

	line_index = 0
	for id_, probab, cs_text, en_text in czeng_file_iter(czeng_file):

		line_index += 1
		log_minor("Cleaning line %s." % line_index)

		cs_tokens = len(en_text.split())
		en_tokens = len(cs_text.split())

		cs_en_min_tokens = min(cs_tokens, en_tokens)
		cs_en_max_tokens = max(cs_tokens, en_tokens)

		if cs_en_min_tokens < min_tokens:
			too_few_token_entries += 1
			continue

		if cs_en_max_tokens > max_tokens:
			too_many_token_entries += 1
			continue

		if no_letter_regex.match(cs_text):
			no_letter_text_entries += 1
			continue

		if no_letter_regex.match(en_text):
			no_letter_text_entries += 1
			continue

		temp_file.write("%s\t%s\t%s\t%s\n" % (id_, probab, cs_text, en_text))

	temp_file.close()

	log_major("Excluding %s too-few-words entries." % too_few_token_entries)
	log_major("Excluding %s too-many-words entries." % too_many_token_entries)
	log_major("Excluding %s no-letter-text entries." % no_letter_text_entries)

	shutil.move(temp_path, czeng_path)

	log_major("Document cleaned.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-c', '--czeng', required=True, type=str)
	parser.add_argument('-m', '--min_tokens', required=False, type=int, default=1)
	parser.add_argument('-x', '--max_tokens', required=False, type=int, default=50)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	czeng_file = codecs.open(args.czeng, "r", "utf-8")

	try:
		czeng_clean(czeng_file, args.czeng, args.min_tokens, args.max_tokens)
		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		czeng_file.close()