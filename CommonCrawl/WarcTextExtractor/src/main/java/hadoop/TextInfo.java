package hadoop;

import java.util.StringTokenizer;


public class TextInfo {

	private static final String SEPARATOR = "\t";
	
	private String language;
	private Double confidence;
	private String uri;
	private String text;
	
	public TextInfo(String language, Double confidence, String uri, String text) {
		this.language = language;
		this.confidence = confidence;
		this.uri = uri;
		this.text = text;
	}
	
	public String getLanguage() {
		return language;
	}
	
	public Double getConfidence() {
		return confidence;
	}

	public String getUri() {
		return uri;
	}
	
	public String getText() {
		return text;
	}
	
	// Note: Below are the methods for serialization.
	
	public static String toCsv(TextInfo textInfo) {
		StringBuilder csvBuilder = new StringBuilder();
		
		csvBuilder.append(textInfo.language).append(SEPARATOR);
		csvBuilder.append(textInfo.confidence).append(SEPARATOR);
		csvBuilder.append(textInfo.uri).append(SEPARATOR);
		csvBuilder.append(textInfo.text).append(SEPARATOR);
		
		csvBuilder.setLength(csvBuilder.length() - 1);
		return csvBuilder.toString();
	}
	
	public static TextInfo fromCsv(String textInfoStr) {
		StringTokenizer csvTokenizer = new StringTokenizer(textInfoStr, SEPARATOR);

		TextInfo textInfo = new TextInfo();
		textInfo.language = new String(csvTokenizer.nextToken());
		textInfo.confidence = new Double(csvTokenizer.nextToken());
		textInfo.uri = new String(csvTokenizer.nextToken());
		textInfo.text = new String(csvTokenizer.nextToken());
		
		return textInfo;
	}
	
	// Note: Below are the utility methods used by serialization.
	
	private TextInfo() {
	}
	
}
