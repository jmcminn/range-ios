import Foundation
import RealmSwift
import SnapKit
import UIKit

/// The table view cell to show comment feed item
/// It also supports showing the details for a Note by adding a noteBackground to the commentTextLabel and making the commentTextLabel
/// text insets bigger for note case.
class CommentFeedItemCell: UITableViewCell {
    let avatarView = UIImageView()
    let authorLabel = UILabel()
    let timestampLabel = UILabel()
    var moreButton: UIButton!
    let noteBackground = NoteBackgroundView()
    var completeButton: RangeButton!
    let commentTextLabel = LabelWithTextInsets()
    let completedLabel = LabelWithTextInsets()

    /// Set when setting the comment
    private var commentId: String?
    private var isCompleted: Bool = false
    /// Required to fetch the comment for actions triggering
    private weak var model: ProjectModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        selectionStyle = .none

        setupViews()

        [avatarView, authorLabel, timestampLabel, moreButton, noteBackground, commentTextLabel, completedLabel]
            .forEach(contentView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().priority(.high)
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }
        authorLabel.snp.makeConstraints { make in
            make.top.lessThanOrEqualToSuperview() // for bigger font when author label is the top most view
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().offset(-56) // place for more button
            make.bottom.equalTo(avatarView.snp.centerY)
        }
        timestampLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().offset(-56) // place for more button
            make.top.equalTo(avatarView.snp.centerY)
        }
        moreButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
            make.centerY.equalTo(avatarView)
            make.trailing.equalToSuperview().inset(16)
        }
        commentTextLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16)
            make.top.greaterThanOrEqualTo(avatarView.snp.bottom).offset(12)
            make.top.greaterThanOrEqualTo(timestampLabel.snp.bottom).offset(12)
        }
        noteBackground.snp.makeConstraints { make in
            make.edges.equalTo(commentTextLabel)
            make.height.greaterThanOrEqualTo(52)
        }
        completedLabel.snp.makeConstraints { make in
            make.top.equalTo(commentTextLabel.snp.bottom)
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().priority(.high)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamic(.Neutral_07)
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true

        authorLabel.textColor = .dynamic(.Neutral_04)
        authorLabel.font = UIFont._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)

        timestampLabel.textColor = .dynamic(.Neutral_05)
        timestampLabel.font = .preferredFont(forTextStyle: .footnote)

        moreButton = FeedItemCells.createMoreButton(handler: { [weak self] _ in
            self?.moreAction()
        })

        noteBackground.backgroundColor = .dynamic(.Neutral_08)

        completeButton = RangeButton(
            configuration: UIButton.Configuration.iconButton(
                backgroundColor: .dynamic(.Neutral_10), foregroundColor: .dynamic(.Neutral_05),
                strokeColor: .dynamic(.Neutral_07), cornerRadius: 16
            ),
            primaryAction: UIAction(image: UIImage(named: "tick.small")) { [weak self] _ in
                self?.toggleCompleteAction()
            }
        )
        .withCustomRangeHighlightColor()
        .withSelectionConfig(backgroundColor: .Green_04, foregroundColor: .Neutral_01, strokeColor: .Green_04)

        completeButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        noteBackground.addSubview(completeButton)
        completeButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
        }

        completedLabel.numberOfLines = 0
        completedLabel.lineBreakMode = .byWordWrapping

        commentTextLabel.textColor = .dynamic(.Neutral_04)
        commentTextLabel.font = .preferredFont(forTextStyle: .subheadline)
        commentTextLabel.numberOfLines = 0
        commentTextLabel.lineBreakMode = .byWordWrapping
    }

    override func prepareForReuse() {
        avatarView.image = nil
        authorLabel.attributedText = nil
        commentTextLabel.attributedText = nil
        completedLabel.attributedText = nil
        isCompleted = false
        commentId = nil
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateCompleteButton()
    }

    /// Updates all the fields
    /// Don't store the Comment as the object might be invalidated while the cell is displayed.
    /// Store the comment id and model so the comment can be fetched if needed.
    func set(comment: Comment, model: ProjectModel) {
        avatarView.image = comment.author?.avatarImage
        commentId = comment.id
        isCompleted = comment.completed
        self.model = model
        authorLabel.attributedText = NSAttributedString(
            string: comment.author?.displayName ?? "",
            attributes: [.strikethroughStyle: comment.author?.strikethroughStyle ?? 0]
        )
        timestampLabel.text = Date.format1(comment.timestamp)

        // only show more button if user is allowed to do any of its actions
        let showMoreButton = model.currentUser.canDelete(comment) || model.currentUser.canEditText(comment)
        moreButton.isHidden = !showMoreButton

        let textString = NSMutableAttributedString(
            string: comment.text,
            attributes: [
                .foregroundColor: UIColor.dynamic(.Neutral_04),
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
            ]
        )
        if comment.textIsEdited {
            textString.append(NSAttributedString(string: " (edited)", attributes: [
                .foregroundColor: UIColor.Neutral_05,
                .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitItalic),
            ]))
        }
        commentTextLabel.attributedText = textString

        if comment.isNote {
            updateCompleteButton()
            commentTextLabel.textInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 50)
            noteBackground.leftBorderRadius = 4
            completeButton.isHidden = false
            noteBackground.statusView.backgroundColor = comment.completed ? .Green_03 : .Orange_03
        } else {
            commentTextLabel.textInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 10)
            noteBackground.leftBorderRadius = 16
            completeButton.isHidden = true
            noteBackground.statusView.backgroundColor = .clear
        }
        updateCompletedLabel(comment: comment)
    }

    /// update complete button for the note completed state
    private func updateCompleteButton() {
        completeButton.isSelected = isCompleted
        completeButton.setImage(
            UIImage(named: "tick.small")?.withTintColor(isCompleted
                ? .Neutral_01
                : .dynamic(.Neutral_05)),
            for: .normal
        )
    }

    /// update the text and insets for completed label
    private func updateCompletedLabel(comment: Comment) {
        if comment.completed, let completedTimestamp = comment.completedTimestamp {
            // distance from view above if it has text, collapse otherwise
            completedLabel.textInsets = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
            let messageString = NSMutableAttributedString(
                string: comment.completedBy?.displayName ?? "",
                attributes: [
                    .foregroundColor: chooseColor(.Neutral_05),
                    .font: UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold),
                    .strikethroughStyle: comment.completedBy?.strikethroughStyle ?? 0,
                ]
            )
            let messageText = " completed this note " + Date.format3(completedTimestamp)
            messageString.append(NSAttributedString(string: messageText, attributes: [
                .foregroundColor: chooseColor(.Neutral_05),
                .font: UIFont.preferredFont(forTextStyle: .caption2),
            ]))

            completedLabel.attributedText = messageString
        } else {
            completedLabel.textInsets = .zero
            completedLabel.attributedText = nil
        }
    }

    private func moreAction() {
        guard let model = model,
              let commentId = commentId,
              let comment = model.mainRealm.object(ofType: Comment.self, forPrimaryKey: commentId) else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowController.moreAction), to: nil, from: self,
            for: FlowEvent(comment)
        )
    }

    private func toggleCompleteAction() {
        guard let model = model,
              let commentId = commentId,
              let comment = model.mainRealm.object(ofType: Comment.self, forPrimaryKey: commentId) else { return }
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.toggleCompleteAction),
            to: nil,
            from: self,
            for: FlowEvent(comment)
        )
    }
}

/// The background for note text.
/// Left and right corners have different radius + there's a strip on the left with color matching the note status
class NoteBackgroundView: UIView {
    /// colored strip on the left side of the view
    let statusView = UIView()
    private let backgroundLayer = CAShapeLayer()
    var leftBorderRadius: CGFloat = 4 {
        didSet {
            updateCorners()
        }
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = .dynamic(.Neutral_08)
        addSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(4)
        }
        backgroundLayer.borderWidth = 1
        backgroundLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(backgroundLayer)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateCorners()
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    /// Update colors that doesn't automatically adapt to appearance change
    private func updateColors() {
        backgroundLayer.strokeColor = chooseColor(.Neutral_07).cgColor
    }

    private func updateCorners() {
        // apply corners to comment background (need this extension as different corners have
        // different radius) and it needs to be calculated when frame changes as we need mask path
        let cornersPath = UIBezierPath(
            roundRect: bounds,
            topLeftRadius: leftBorderRadius,
            topRightRadius: 16,
            bottomLeftRadius: leftBorderRadius,
            bottomRightRadius: 16
        ).cgPath
        let noteBackgroundMask = CAShapeLayer()
        noteBackgroundMask.path = cornersPath
        layer.mask = noteBackgroundMask

        backgroundLayer.path = cornersPath
    }
}
