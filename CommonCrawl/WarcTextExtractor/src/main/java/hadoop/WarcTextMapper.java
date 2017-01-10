package hadoop;

import htmlutils.TextsParser;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.charset.Charset;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.ListIterator;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import langdetect.LanguageDetectorBuilder2;

import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.log4j.Logger;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.safety.Cleaner;
import org.jsoup.safety.Whitelist;
import org.jsoup.select.Elements;

import com.martinkl.warc.WARCRecord;
import com.martinkl.warc.WARCWritable;
import com.optimaize.langdetect.DetectedLanguage;
import com.optimaize.langdetect.LanguageDetector;
import com.optimaize.langdetect.ngram.NgramExtractors;
import com.optimaize.langdetect.profiles.LanguageProfileReader;


public class WarcTextMapper extends Mapper<LongWritable, WARCWritable, Text, Text> {	
	
	private static enum Counters {
		MAPPER_OUTPUTS, 
		MAPPER_INVALID_RECORDS, 
		MAPPER_INVALID_FILES
	}
	
	private static final Logger LOGGER = Logger.getLogger(WarcTextMapper.class);
	
	private static final Pattern HTTP_HEADER_SPLITTER = Pattern.compile("\r\n\r\n");
	private static final Pattern HTTP_CONTENT_TYPE_PARSER = Pattern.compile("Content-Type:(.*)", Pattern.CASE_INSENSITIVE);
	private static final Pattern HTTP_CHARSET_PARSER = Pattern.compile("(?:charset)(?:=)(.*)", Pattern.CASE_INSENSITIVE);
	private static final Pattern HTTP_CHARSET_CLEANER = Pattern.compile("[^\\w-]");
	private static final Pattern HTTP_MIME_TYPE_PARSER = Pattern.compile("([^;]*);?");
	private static final Pattern SPACE_SEQ_CLEANER = Pattern.compile("[\\p{Z}\\p{C}]+");
	private static final Pattern SPECIALS_FINDER = Pattern.compile("\\p{InSpecials}");
	
	private Args arguments;
	private Cleaner documentCleaner;
	private LanguageDetector languageDetector;

	private final Text outputKey = new Text();
	private final Text outputValue = new Text();

	protected void setup(Context context) throws IOException, InterruptedException {
		super.setup(context);

		arguments = Args.fromConf(context.getConfiguration());
		documentCleaner = new Cleaner(Whitelist.relaxed());
		languageDetector = LanguageDetectorBuilder2.create(NgramExtractors.standard())
				.withProfiles(new LanguageProfileReader().readAllBuiltIn()).build();
	}
	
	public void run(Context context) throws IOException, InterruptedException {
		try {
			super.run(context);
			
		} catch (RuntimeException cause) {
			LOGGER.error("Invalid WARC file!", cause);
			context.getCounter(Counters.MAPPER_INVALID_FILES).increment(1L);
		}
	}

	public void map(LongWritable key, WARCWritable value, Context context) throws IOException, InterruptedException {
		try {
			WARCRecord warcRecord = value.getRecord();
			WARCRecord.Header warcHeader = warcRecord.getHeader();

			String warcRecordType = warcHeader.getRecordType();
			if (!warcRecordType.equals("response")) return;

			String httpUri = warcHeader.getTargetURI();
			String httpDomain = parseHttpDomain(httpUri);

			byte[] httpContent = warcRecord.getContent();
			String httpHeader = parseHttpHeader(httpContent);
			String httpContentType = parseContentType(httpHeader);
			if (httpContentType == null) return;

			String httpMimeType = parseMimeType(httpContentType);
			if (httpMimeType == null || !httpMimeType.equals("text/html")) return;

			String httpCharset = resolveCharset(parseCharset(httpContentType));
			Document document = parseDocument(httpContent, httpCharset, httpUri);
			
			List<String> texts = filterTexts(cleanTexts(parseParagraphTexts(document)));
			List<TextInfo> textInfos = filterTextInfos(detectTexts(httpUri, texts));
			
			for (TextInfo textInfo : textInfos) {
				outputKey.set(httpDomain);
				outputValue.set(TextInfo.toCsv(textInfo));
				
				context.write(outputKey, outputValue);
				context.getCounter(Counters.MAPPER_OUTPUTS).increment(1L);
			}

		} catch (RuntimeException cause) {
			LOGGER.error("Invalid WARC record!", cause);
			context.getCounter(Counters.MAPPER_INVALID_RECORDS).increment(1L);
		}
	}
	
	private String parseHttpDomain(String uri) {
		try {
			return new URI(uri).getHost();
		
		} catch (URISyntaxException cause) {
			throw new RuntimeException(cause);
		}
	}
	
	private String parseHttpHeader(byte[] httpContent) {
		try {
			String httpContentStr = new String(httpContent);
			return HTTP_HEADER_SPLITTER.split(httpContentStr, 2)[0];
			
		} catch (RuntimeException cause) {
			throw new RuntimeException ("Failed parsing HTTP header!", cause);
		}
	}
	
	private String parseContentType(String httpHeader) {
		Matcher matcher = HTTP_CONTENT_TYPE_PARSER.matcher(httpHeader);
		if (!matcher.find()) return null;
		
		return matcher.group(1).trim().toLowerCase();
	}

	private String parseMimeType(String httpContentType) {
		Matcher matcher = HTTP_MIME_TYPE_PARSER.matcher(httpContentType);
		if (!matcher.find()) return null;
		
		return matcher.group(1).trim().toLowerCase(); 
	}

	private String parseCharset(String httpContentType) {
		Matcher matcher = HTTP_CHARSET_PARSER.matcher(httpContentType);
		if (!matcher.find()) return null;
		
		return matcher.group(1).trim().toLowerCase(); 
	}
	
	private String resolveCharset(String charset) {
		if (charset == null) return "UTF-8";
		
		String cleanedCharset = cleanCharset(charset);
		if (!isSupportedCharset(cleanedCharset)) return "UTF-8";
		
		return cleanedCharset;
	}
	
	private String cleanCharset(String charset) {
		return HTTP_CHARSET_CLEANER.matcher(charset).replaceAll("");
	}
	
	private boolean isSupportedCharset(String charset) {
		try {
			return Charset.isSupported(charset);
			
		} catch (RuntimeException cause) {
			return false;
		}
	}

	private Document parseDocument(byte[] httpContent, String httpCharset, String httpUri) {
		Document bestCharsetDocument = null;
		int bestCharsetInvalidity = Integer.MAX_VALUE;
		
		for (String charset : charsetPlan(httpCharset)) {
			try {
				InputStream httpContentStream = new ByteArrayInputStream(httpContent);
				Document document = Jsoup.parse(httpContentStream, charset, httpUri);
				int charsetInvalidity = charsetInvalidity(document.text());

				if (charsetInvalidity < bestCharsetInvalidity) {
					bestCharsetDocument = documentCleaner.clean(document);
					bestCharsetInvalidity = charsetInvalidity;
				}
				
				if (bestCharsetInvalidity == 0) return bestCharsetDocument;
				
			} catch (IOException | RuntimeException cause) {
			}
		}
		
		return bestCharsetDocument;
	}
	
	private List<String> charsetPlan(String httpCharset) {
		List<String> charsetPlan = new LinkedList<>();
		charsetPlan.add(httpCharset);

		for (String charset : arguments.getCharsets()) {
			if (charsetPlan.contains(charset)) continue;
			charsetPlan.add(charset);
		}
		
		return charsetPlan;
	}
	
	private int charsetInvalidity(String text) {
		int charsetInvalidty = 0;
		
		Matcher matcher = SPECIALS_FINDER.matcher(text);
		while (matcher.find()) charsetInvalidty++;
		
		return charsetInvalidty;
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

	// Note: Below is an alternative method for parsing texts.
	
	@SuppressWarnings("unused")
	private List<String> parseAnyTexts(Document document) {
		Element bodyElement = document.body();
		if (bodyElement == null) return new LinkedList<>();
		
		TextsParser textsParser = new TextsParser();
		bodyElement.traverse(textsParser);
		
		return textsParser.getTexts();
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
	
	private List<TextInfo> detectTexts(String uri, List<String> texts) {
		List<TextInfo> textInfos = new LinkedList<>();
		
		for (Iterator<String> iter = texts.listIterator(); iter.hasNext();) {
			String text = iter.next();
			
			List<DetectedLanguage> detectedLanguages = languageDetector.getProbabilities(text);
			DetectedLanguage detectedLanguage = detectedLanguages.isEmpty() ? null : detectedLanguages.get(0); 
			
			String language = detectedLanguage == null ? null : detectedLanguage.getLocale().getLanguage(); 
			Double confidence = detectedLanguage == null ? null : detectedLanguage.getProbability();
			
			textInfos.add(new TextInfo(language, confidence, uri, text));
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
	
}
