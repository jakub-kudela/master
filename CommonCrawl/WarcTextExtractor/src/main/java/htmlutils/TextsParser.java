package htmlutils;

import java.util.LinkedList;
import java.util.List;

import org.jsoup.nodes.Element;
import org.jsoup.nodes.Node;
import org.jsoup.select.NodeVisitor;


public class TextsParser implements NodeVisitor {

	private final List<String> texts;
	
	public TextsParser() {
		texts = new LinkedList<>();
	}
	
	public List<String> getTexts() {
		return texts;
	}
	
	@Override
	public void head(Node node, int depth) {
		if (!(node instanceof Element)) return;
		Element element = (Element) node;
		
		String ownText = element.ownText();
		if (ownText.isEmpty()) return;
		
		String allText = element.text();
		texts.add(allText);
	}
	
	@Override
	public void tail(Node node, int depth) {
	}

}
