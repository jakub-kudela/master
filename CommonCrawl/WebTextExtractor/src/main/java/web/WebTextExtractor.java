package web;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.ListIterator;
import java.util.Queue;
import java.util.Set;
import java.util.regex.Pattern;

import langdetect.LanguageDetectorBuilder2;

import org.apache.commons.io.IOUtils;
import org.apache.log4j.Logger;
import org.jsoup.Connection.Response;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.safety.Cleaner;
import org.jsoup.safety.Whitelist;
import org.jsoup.select.Elements;

import com.optimaize.langdetect.DetectedLanguage;
import com.optimaize.langdetect.LanguageDetector;
import com.optimaize.langdetect.ngram.NgramExtractors;
import com.optimaize.langdetect.profiles.LanguageProfileReader;


public class WebTextExtractor {
	
	private static class UriQueueItem {
		
		final String uri;
		final int depth;
		
		UriQueueItem(String uri, int depth) {
			this.uri = uri;
			this.depth = depth;
		}
		
	}
	
	private static final Logger LOGGER = Logger.getLogger(WebTextExtractor.class);
	
	private static final Pattern SPACE_SEQ_CLEANER = Pattern.compile("[\\p{Z}\\p{C}]+");
	private static final Pattern SPECIALS_FINDER = Pattern.compile("\\p{InSpecials}");
	
	private final Args arguments;
	private final Cleaner documentCleaner;
	private final LanguageDetector languageDetector;
	
	private final BufferedReader seedsReader;
	private final BufferedWriter textsWriter;
	
	private final Queue<UriQueueItem> uriQueue; 
	private final Set<Integer> uriHashes;
	private final Set<Integer> textHashes;
	
	public WebTextExtractor(Args arguments) throws IOException {
		this.arguments = arguments;
		documentCleaner = new Cleaner(Whitelist.relaxed());
		languageDetector = LanguageDetectorBuilder2.create(NgramExtractors.standard())
				.withProfiles(new LanguageProfileReader().readAllBuiltIn()).build();
		
		uriQueue = new LinkedList<>();
		seedsReader = new BufferedReader(new InputStreamReader(new FileInputStream(arguments.getSeedsPath()), "UTF-8"));
		textsWriter = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(arguments.getTextsPath()), "UTF-8"));
		
		uriHashes = new HashSet<>();
		textHashes = new HashSet<>();
	}
	
	@Override
	protected void finalize() throws Throwable {
		IOUtils.closeQuietly(seedsReader);
		IOUtils.closeQuietly(textsWriter);
		
		super.finalize();
	}

	public void run() throws IOException {
		initializeUriQueue();
		processUriQueue();
	}
	
	private void initializeUriQueue() {
		try {
			String seed = null;
			while ((seed = seedsReader.readLine())!= null) {
				uriQueue.add(new UriQueueItem(seed, 0));
			}
		
		} catch (IOException cause) {
			LOGGER.warn("Invalid seeds file!", cause);
			throw new RuntimeException(cause);
		}
	}
	
	private void processUriQueue() {
		while (!uriQueue.isEmpty()) {
			processUriQueueItem();
		}
	}
	
	private void processUriQueueItem() {
		try {
			UriQueueItem item = uriQueue.remove();
			String domain = parseDomain(item.uri);

			// Check if the link has not been already processed. 
			int uriHash = item.uri.hashCode();
			if (!uriHashes.add(uriHash)) return;
			
			// Process the request, get and clean the document.
			LOGGER.info(String.format("Processing: %s.", item.uri));
			Response response = Jsoup.connect(item.uri).timeout(10000).execute();
			if (!response.contentType().equals("text/html")) ;

			Document document = response.parse();
			document = documentCleaner.clean(document);

			// Parse the texts, identify their language and filter those not meeting criteria.
			List<String> texts = filterTexts(cleanTexts(parseParagraphTexts(document)));
			List<TextInfo> textInfos = filterTextInfos(detectTexts(domain, item.uri, texts));

			// Print all of the unique texts that has left.
			for (TextInfo textInfo : textInfos) {
				int textHash = textInfo.getText().hashCode();
				if (!textHashes.add(textHash)) continue;
				
				String textInfoLine = TextInfo.toCsv(textInfo);
				textsWriter.write(textInfoLine);
				textsWriter.newLine();
			}
			
			// Check if we have reached the maximum allowed depth.
			if (item.depth == arguments.getMaxDepth()) return;
			
			// Parse all of the links on the document and remove those pointing 
			List<String> links = parseLinks(document);
			
			// Enqueue all of the non-anchor links to the same domain. 
			for (String link : links) {
				if (link.contains("#")) continue;
				
				String linkDomain = parseDomain(link);
				if (linkDomain == null) continue;
				if (!domain.equals(linkDomain)) continue;
				
				uriQueue.add(new UriQueueItem(link, item.depth + 1));
			}
			
		} catch (Exception cause) {
			LOGGER.error("Invalid url queue item!", cause);
		}
	}
	
	private String parseDomain(String uri) {
		try {
			return new URI(uri).getHost();
			
		} catch (URISyntaxException cause) {
			return null;
		}
	}
	
	private List<String> parseParagraphTexts(Document document) {
		List<String> texts = new LinkedList<>();
		
		Element bodyElement = document.body();
		if (bodyElement == null) return texts;

		Elements pElements = bodyElement.select("p");
		for (Element pElement : pElements) {
			texts.add(pElement.text());
		}
		
		return texts;
	}
	
	private List<String> cleanTexts(List<String> texts) {
		for (ListIterator<String> iter = texts.listIterator(); iter.hasNext();) {
			String dirtyText = iter.next();
			String cleanText = SPACE_SEQ_CLEANER.matcher(dirtyText).replaceAll(" ");
			iter.set(cleanText.trim());
		}
		
		return texts;
	}
	
	private List<String> filterTexts(List<String> texts) {
		for (Iterator<String> iter = texts.listIterator(); iter.hasNext();) {
			String text = iter.next();
			
			if (text.length() < arguments.getTextLength()) {
				iter.remove();
				continue;
			
			} else if (SPECIALS_FINDER.matcher(text).find()) {
				iter.remove();
				continue;
			}
		}
		
		return texts;
	}
	
	private List<TextInfo> detectTexts(String domain, String uri, List<String> texts) {
		List<TextInfo> textInfos = new LinkedList<>();
		
		for (Iterator<String> iter = texts.listIterator(); iter.hasNext();){
			String text = iter.next();
			
			List<DetectedLanguage> detectedLanguages = languageDetector.getProbabilities(text);
			DetectedLanguage detectedLanguage = detectedLanguages.isEmpty() ? null : detectedLanguages.get(0); 
			
			String language = detectedLanguage == null ? null : detectedLanguage.getLocale().getLanguage(); 
			Double confidence = detectedLanguage == null ? null : detectedLanguage.getProbability();
			
			textInfos.add(new TextInfo(domain, language, confidence, uri, text));
		}
		
		return textInfos;
	}
	
	private List<TextInfo> filterTextInfos(List<TextInfo> textInfos) {
		for (Iterator<TextInfo> iter = textInfos.listIterator(); iter.hasNext();) {
			TextInfo textInfo = iter.next();
			
			if (textInfo.getLanguage() == null || textInfo.getConfidence() == null) {
				iter.remove();
				continue;
				
			} else if (!arguments.hasLanguage(textInfo.getLanguage())) {
				iter.remove();
				continue;

			} else if (textInfo.getConfidence() < arguments.getLanguageConfidence()) {
				iter.remove();
				continue;
			}
		}
		
		return textInfos;
	}
	
	private List<String> parseLinks(Document document) {
		List<String> links = new LinkedList<>();
		
		Element bodyElement = document.body();
		if (bodyElement == null) return links;

		Elements aElements = bodyElement.select("a[href]");
		for (Element aElement : aElements) {
			links.add(aElement.attr("abs:href"));
		}
		
		return links;
	}
	
}
