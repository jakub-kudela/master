#!/usr/bin/env python

import os
import sys
import argparse
import codecs
import logging
import time
import math
import random
import operator

from pybrain.datasets import ClassificationDataSet
from pybrain.utilities import percentError
from pybrain.tools.shortcuts import buildNetwork
from pybrain.supervised.trainers import BackpropTrainer
from pybrain.structure.modules import SoftmaxLayer
from pybrain.structure import TanhLayer
from pybrain.tools.xml import NetworkWriter


logger_freq = 2
logger_timestamp = time.time()
logger = logging.getLogger(__file__)
logging.getLogger().handlers = []

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

def weight_file_iter(weight_file):
	for line in weight_file:

		tokens = line.strip().split()
		
		src_word = tokens[0]
		trg_word = tokens[1]
		weight = float(tokens[2])

		yield((src_word, trg_word, weight))

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

def calc_length_sim(src_doc_text, trg_doc_text, len_mean, len_std):
	# Target length likelihood modeling based on normal distribution.
	# We measure the document length difference by characters, not words.
	
	likelihood = lambda x, m, sd: math.exp(-(((x - m) / float(sd)) ** 2.) / 2.)
	src_length, trg_length = float(len(src_doc_text)), float(len(trg_doc_text))

	length_sim = likelihood(trg_length / src_length, len_mean, len_std)
	length_conf = 1. - math.exp(-0.01 * src_length)
	return (length_sim, length_conf)

def calc_weight_sim(src_doc_text, trg_doc_text, weights):
	src_words, trg_words = src_doc_text.split(), trg_doc_text.split()
	src_size, trg_size = float(len(src_words)), float(len(trg_words))
	null_weights = {}

	total_length = 0.
	resolved_length = 0.
	matching_length = 0.

	for src_word in src_words:

		src_max_weight = None
		src_weights = weights.get(src_word, null_weights)

		for trg_word in trg_words:	
			weight = src_weights.get(trg_word, None)
			if not weight and trg_word == src_word: weight = 1.
			src_max_weight = max(weight, src_max_weight)

		src_word_length = float(len(src_word))
		total_length += src_word_length

		if src_max_weight:
			resolved_length += src_word_length
			matching_length += src_max_weight * src_word_length

	weight_sim = matching_length / resolved_length if resolved_length > 0. else 0.
	weight_conf = resolved_length / total_length if total_length > 0. else 0.
	return (weight_sim, weight_conf)

def train_classifier(align_file, src_doc_file, trg_doc_file, len_mean, len_std, weight_file, output):
	# Classification with Feed-Forward Neural Networks.
	# http://pybrain.org/docs/tutorial/fnn.html

	log_major("Loading weights ...")

	weights = {}

	weight_index = 0
	for src_word, trg_word, weight in weight_file_iter(weight_file):

		weight_index += 1
		log_minor("Loading weight %s." % weight_index)

		src_weights = weights.get(src_word, {})
		weights[src_word] = src_weights
		src_weights[trg_word] = weight

	log_major("Weights loaded.")
	log_major("Preparing bins ...")

	align_bin_iter = align_file_bin_iter(align_file)
	src_bin_iter = doc_file_bin_iter(src_doc_file)
	trg_bin_iter = doc_file_bin_iter(trg_doc_file)
	align_item, src_item, trg_item = None, None, None

	subsampling, sample_pos_ratio = 0.2, 0.5
	sample_neg_ratio = 1. - sample_pos_ratio

	seen_positives, seen_negatives = 1e-9, 1e-9
	all_data = []

	align_index = 0
	while True:

		if not align_item: align_item = next(align_bin_iter, None)
		if not src_item: src_item = next(src_bin_iter, None)
		if not trg_item: trg_item = next(trg_bin_iter, None)
		if not align_item or not src_item or not trg_item: break

		align_bin, aligns = align_item
		src_bin, src_docs = src_item
		trg_bin, trg_docs = trg_item

		if align_bin < max(src_bin, trg_bin): align_item = None
		if src_bin < max(align_bin, trg_bin): src_item = None
		if trg_bin < max(align_bin, src_bin): trg_item = None
		if not align_bin == src_bin == trg_bin: continue

		log_major("Preparing bin '%s' ..." % align_bin)

		for src_doc_id, src_aligns in aligns.items():

			align_index += 1
			log_minor("Preparing data %s." % align_index)

			src_aligns.sort(key=operator.itemgetter(1), reverse=True)
			src_doc_text = src_docs[src_doc_id]
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

			if mindex == 0: seen_positives += 1
			if mindex == None: seen_negatives += 1

			if mindex == 0 or mindex == None:
				seen_pos_ratio = seen_positives / (seen_positives + seen_negatives)
				pos_probab = subsampling * sample_pos_ratio / seen_pos_ratio
				if mindex == 0 and random.random() > pos_probab: continue

				seen_neg_ratio = seen_negatives / (seen_negatives + seen_positives)
				neg_probab = subsampling * sample_neg_ratio / seen_neg_ratio
				if mindex == None and random.random() > neg_probab: continue

				top_src_align = src_aligns[0]
				trg_doc_id = top_src_align[0]
				trg_doc_text = trg_docs[trg_doc_id]

				length_sim, length_conf = calc_length_sim(src_doc_text, trg_doc_text, len_mean, len_std)
				weight_sim, weight_conf = calc_weight_sim(src_doc_text, trg_doc_text, weights)
				
				inp = [length_sim, length_conf, weight_sim, weight_conf]
				out = [1] if mindex == 0 else [0]
				all_data.append((inp, out))

		log_major("Bin '%s' prepared." % align_bin)

		align_item, src_item, trg_item = None, None, None

	log_major("All bins prepared.")
	log_major("Training classifier.")

	indim, outdim = len(all_data[0][0]), len(all_data[0][1])
	train_data = ClassificationDataSet(indim, outdim, nb_classes=2)
	test_data = ClassificationDataSet(indim, outdim, nb_classes=2)

	for inp, out in all_data:
		data = train_data if random.random() > 0.8 else test_data
		data.addSample(inp, out)

	train_data._convertToOneOfMany()
	test_data._convertToOneOfMany()

	hiddim = train_data.indim ** 2
	indim, outdim = train_data.indim, train_data.outdim
	fnn = buildNetwork(indim, hiddim, outdim, outclass=SoftmaxLayer)
	trainer = BackpropTrainer(fnn, dataset=train_data, learningrate=0.01)

	for epoch in range(20):

		log_major("Training epoch %s." % epoch)
		trainer.train()

		train_error = percentError(trainer.testOnClassData(dataset=train_data), train_data['class'])
		test_error = percentError(trainer.testOnClassData(dataset=test_data), test_data['class'])

		log_major("Training data error: %5.2f %%." % train_error)
		log_major("Testing data error: %5.2f %%." % test_error)

	log_major("Classifier trained.")	
	log_major("Saving classifier ...")

	NetworkWriter.writeToFile(fnn, output)

	log_major("Classifier saved.")


if __name__ == "__main__":
	logging_format = '>>> [%(filename)s][%(asctime)s] %(message)s'
	logging.basicConfig(stream=sys.stdout, format=logging_format, level=logging.INFO)

	parser = argparse.ArgumentParser(prog=__file__, add_help=False)
	parser.add_argument('-a', '--align', required=True, type=str)
	parser.add_argument('-s', '--src_doc', required=True, type=str)
	parser.add_argument('-t', '--trg_doc', required=True, type=str)
	parser.add_argument('-m', '--len_mean', type=float, default=1.0)
	parser.add_argument('-d', '--len_std', type=float, default=0.5)
	parser.add_argument('-w', '--weight', required=True, type=str)
	parser.add_argument('-o', '--output', required=True, type=str)
	args = parser.parse_args()

	log_major("Starting execution in %s." % os.getcwd())
	for arg in vars(args): log_major("Option --%s = %s." % (arg, getattr(args, arg)))

	align_file = codecs.open(args.align, "r", "utf-8")
	src_doc_file = codecs.open(args.src_doc, "r", "utf-8")
	trg_doc_file = codecs.open(args.trg_doc, "r", "utf-8")
	weight_file = codecs.open(args.weight, "r", "utf-8")

	try:
		train_classifier(align_file, src_doc_file, trg_doc_file, 
			args.len_mean, args.len_std, weight_file, args.output)

		log_major("Script ended successfully.")
	except:
		log_major("Script ended unsucessfully!")
	finally:
		align_file.close()
		src_doc_file.close()
		trg_doc_file.close()
		weight_file.close()
