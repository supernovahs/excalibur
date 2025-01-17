use std::fmt::{self, Display};

use datatypes::portfolio::coin::Coin;
use iced::Padding;
use iced_aw::{graphics::icons::icon_to_char, Icon, ICON_FONT};

use super::*;
use crate::components::{
    select::excalibur_select,
    system::{
        ExcaliburButton, ExcaliburChart, ExcaliburColor, ExcaliburContainer, ExcaliburHistogram,
        ExcaliburInputBuilder, ExcaliburText, ExcaliburTooltip,
    },
};

#[derive(Debug, Clone, Default, Copy, PartialEq, Eq, Hash)]
pub enum SubmitState {
    #[default]
    Empty,
    Pending,
    Confirmed,
    Failed,
}

#[derive(Debug, Clone, Default)]
pub struct Form {
    pub amount: Option<String>,
    pub coins: Vec<Coin>,
    pub chosen_asset: Option<Coin>,
    pub chosen_quote: Option<Coin>,
    pub duration: Option<Times>,
    pub end_price: Option<String>,
    pub liquidity: Option<LiquidityTypes>,
    pub state: SubmitState,
    pub error: Option<String>,
}

impl Form {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn reset(&mut self) {
        self.amount = None;
        self.chosen_asset = None;
        self.chosen_quote = None;
        self.duration = None;
        self.end_price = None;
        self.liquidity = None;
        self.state = SubmitState::Empty;
    }

    pub fn pending(&mut self) {
        self.state = SubmitState::Pending;
    }

    pub fn confirmed(&mut self) {
        self.state = SubmitState::Confirmed;
    }

    pub fn failed(&mut self) {
        self.state = SubmitState::Failed;
    }

    #[allow(dead_code)]
    pub fn validate_amount(&mut self) {
        self.error = None; // Reset error before validation

        match &self.amount {
            Some(amount_str) => match amount_str.parse::<f64>() {
                Ok(amount) => {
                    if amount < 0.0 {
                        self.error = Some("Amount cannot be negative".into());
                    }
                }
                Err(_) => self.error = Some("Amount is not a valid number".into()),
            },
            None => self.error = Some("Amount is not provided".into()),
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn view<'a, Message>(
        &'a self,
        preview_chart: &'a ExcaliburHistogram,
        state: &SubmitState,
        on_close: Option<Message>,
        submit: Option<Message>,
        on_change_deposit: impl Fn(Option<String>) -> Message + 'a,
        on_select_asset: impl Fn(Coin) -> Message + 'a,
        on_select_quote: impl Fn(Coin) -> Message + 'a,
        on_select_duration: impl Fn(Times) -> Message + 'a,
        on_change_end_price: impl Fn(Option<String>) -> Message + 'a,
        on_select_liquidity: impl Fn(LiquidityTypes) -> Message + 'a,
        liquidity_choices: &[LiquidityChoices],
    ) -> Element<'_, Message>
    where
        Message: 'a + Default + Clone,
    {
        FormView::layout(
            FormView::form_content(
                FormView::strategy_form(
                    self.coins.clone(),
                    self.chosen_asset.clone(),
                    self.chosen_quote.clone(),
                    on_select_asset,
                    on_select_quote,
                    Times::to_options(),
                    self.duration,
                    on_select_duration,
                    self.end_price.clone(),
                    on_change_end_price,
                    LiquidityTypes::all(),
                    self.liquidity,
                    on_select_liquidity,
                    liquidity_choices,
                ),
                FormView::deposit_form(
                    self.amount.clone(),
                    on_change_deposit,
                    FormView::form_item(
                        "Instructions",
                        Column::new().padding(Sizes::Lg).push(label("Choose a strategy template and deposit amount, then submit the transaction to allocate.").secondary().footnote())
                    ),
                    submit,
                    state,
                    &self.error
                ),
                FormView::chart_layout_histogram(
                    preview_chart,
                    label("Liquidity Preview").secondary(),
                    label("Synced").caption2().tertiary(),
                ),
            ),
            on_close,
        )
        .into()
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Hash, Copy)]
pub enum LiquidityTypes {
    Low,
    #[default]
    Med,
    High,
}

#[derive(Debug, Clone, Default)]
pub struct LiquidityTemplateParameters {
    pub strike_price_wad: f64,
    pub sigma_percent_wad: f64,
    pub time_remaining_years_wad: f64,
}

impl LiquidityTypes {
    pub fn all() -> Vec<Self> {
        vec![Self::Low, Self::Med, Self::High]
    }

    // todo: work on this!
    pub fn to_parameters(self, current_price: f64) -> LiquidityTemplateParameters {
        match self {
            LiquidityTypes::Low => LiquidityTemplateParameters {
                strike_price_wad: current_price,
                sigma_percent_wad: 0.85,
                time_remaining_years_wad: 1.0,
            },
            LiquidityTypes::Med => LiquidityTemplateParameters {
                strike_price_wad: current_price,
                sigma_percent_wad: 0.625,
                time_remaining_years_wad: 1.0,
            },
            LiquidityTypes::High => LiquidityTemplateParameters {
                strike_price_wad: current_price,
                sigma_percent_wad: 0.1,
                time_remaining_years_wad: 1.0,
            },
        }
    }
}

impl std::fmt::Display for LiquidityTypes {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LiquidityTypes::Low => write!(f, "Low"),
            LiquidityTypes::Med => write!(f, "Medium"),
            LiquidityTypes::High => write!(f, "High"),
        }
    }
}

impl std::fmt::Display for LiquidityTemplateParameters {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let formatted_strike_price = format!("${:.2}", self.strike_price_wad);
        let formatted_volatility = format!("{:.2}%", self.sigma_percent_wad * 100.0);
        let formatted_days_until_expiration =
            format!("{:.0}", self.time_remaining_years_wad * 365.0);

        write!(
            f,
            "strike: {} volatility: {} expires in: ~{} days",
            formatted_strike_price, formatted_volatility, formatted_days_until_expiration
        )
    }
}

pub fn space_between<'a, Message>(
    left: impl Into<Element<'a, Message>>,
    right: impl Into<Element<'a, Message>>,
) -> Row<'a, Message>
where
    Message: 'a,
{
    Row::new()
        .push(Column::new().width(Length::Fill).push(left))
        .push(
            Column::new()
                .width(Length::Fill)
                .align_items(alignment::Alignment::End)
                .push(right),
        )
        .align_items(alignment::Alignment::Center)
        .width(Length::Fill)
}

#[derive(Debug, Clone, Default)]
pub struct FormView;

impl FormView {
    pub fn layout<'a, Message>(
        form_content: impl Into<Element<'a, Message>>,
        on_close: Option<Message>,
    ) -> Container<'a, Message>
    where
        Message: 'a + Clone,
    {
        ExcaliburContainer::default().transparent().build(
            Column::new()
                .width(Length::Fill)
                .spacing(Sizes::Lg)
                .push(Self::header("Create new position", "ETH/USDC", on_close))
                .push(form_content),
        )
    }

    pub fn header<'a, Message>(
        subtitle: impl ToString,
        title: impl ToString,
        on_close: Option<Message>,
    ) -> Row<'a, Message>
    where
        Message: 'a + Clone,
    {
        space_between(
            Column::new()
                .spacing(Sizes::Sm)
                .push(label(subtitle).secondary().build())
                .push(label(title).title1().build()),
            ExcaliburButton::new()
                .transparent()
                .build(
                    label(icon_to_char(Icon::X))
                        .icon()
                        .headline()
                        .secondary()
                        .build(),
                )
                .on_press_maybe(on_close),
        )
    }

    /// Layout of the entire create position form, including preview chart.
    pub fn form_content<'a, Message>(
        strategy_form: impl Into<Element<'a, Message>>,
        deposit_form: impl Into<Element<'a, Message>>,
        chart: impl Into<Element<'a, Message>>,
    ) -> Column<'a, Message>
    where
        Message: 'a,
    {
        Column::new()
            .spacing(Sizes::Md)
            .width(Length::Fill)
            .push(
                Row::new()
                    .spacing(Sizes::Md)
                    .push(
                        Column::new()
                            .width(Length::FillPortion(2))
                            .push(strategy_form.into()),
                    )
                    .push(
                        Column::new()
                            .width(Length::FillPortion(3))
                            .spacing(Sizes::Md)
                            .push(chart.into()),
                    )
                    .width(Length::Fill),
            )
            .push(deposit_form.into())
    }

    /// Layout of the deposit input, review summary, and submit button.
    pub fn deposit_form<'a, Message>(
        deposit_amount: Option<String>,
        on_change_deposit: impl Fn(Option<String>) -> Message + 'a,
        review: impl Into<Element<'a, Message>>,
        submit: Option<Message>,
        state: &SubmitState,
        error: &'a Option<String>,
    ) -> Container<'a, Message>
    where
        Message: 'a + Clone + Default,
    {
        let mut row = Row::new()
            .width(Length::Fill)
            .spacing(Sizes::Md)
            .push(
                Self::deposit_input(deposit_amount, on_change_deposit)
                    .width(Length::FillPortion(2)),
            )
            .push(
                Row::new()
                    .spacing(Sizes::Sm)
                    .width(Length::FillPortion(3))
                    .push(Container::new(review.into()).width(Length::FillPortion(2)))
                    .push(Self::submit(submit, state).width(Length::FillPortion(2))),
            );

        // Add the error message to the row if it exists
        if let Some(error_message) = error {
            row = row.push(Text::new(error_message));
        }

        ExcaliburContainer::default().transparent().build(row)
    }

    /// Simple column of rows of review item elements.
    #[allow(dead_code)]
    pub fn review_summary<'a, Message>(
        title: impl ToString,
        rows: Vec<impl Into<Element<'a, Message>>>,
    ) -> Container<'a, Message>
    where
        Message: 'a + Default,
    {
        Self::form_item(
            title,
            Column::with_children(rows.into_iter().map(|x| x.into()).collect::<Vec<_>>())
                .spacing(Sizes::Sm)
                .padding(Sizes::Md),
        )
    }

    /// Layout of the strategy selections to choose from.
    /// todo: add a toggle to switch to advanced mode that lets you choose.
    #[allow(clippy::too_many_arguments)]
    pub fn strategy_form<'a, Message>(
        _choice_assets: Vec<Coin>,
        _chosen_asset: Option<Coin>,
        _chosen_quote: Option<Coin>,
        _on_select_asset: impl Fn(Coin) -> Message + 'a,
        _on_select_quote: impl Fn(Coin) -> Message + 'a,
        _choice_duration: Vec<Times>,
        _chosen_duration: Option<Times>,
        _on_select_duration: impl Fn(Times) -> Message + 'a,
        _end_price: Option<String>,
        _on_change_end_price: impl Fn(Option<String>) -> Message + 'a,
        _choice_liquidity: Vec<LiquidityTypes>,
        chosen_liquidity: Option<LiquidityTypes>,
        on_select_liquidity: impl Fn(LiquidityTypes) -> Message + 'a,
        liquidity_choices: &[LiquidityChoices],
    ) -> Container<'a, Message>
    where
        Message: 'a + Default + Clone,
    {
        ExcaliburContainer::default().transparent().build(
            Column::new().spacing(Sizes::Md).push(
                Column::new()
                    .spacing(Sizes::Md)
                    .push(label("Choose liquidity concentration").secondary().build())
                    .push(
                        Column::with_children(
                            liquidity_choices
                                .iter()
                                .map(|x| {
                                    Self::strategy_template(
                                        Some(on_select_liquidity(x.liquidity_type)),
                                        x.liquidity_type,
                                        chosen_liquidity == Some(x.liquidity_type),
                                        x.liquidity_type.to_parameters(x.last_price),
                                        format!(
                                            "${:.2} - ${:.2}",
                                            x.price_range.0, x.price_range.1
                                        ),
                                    )
                                    .width(Length::Fill)
                                    .into()
                                })
                                .collect::<Vec<_>>(),
                        )
                        .spacing(Sizes::Md),
                    ),
            ),
        )
    }

    /// "Cast" for each strategy template option.
    pub fn strategy_template<'a, Message>(
        on_press: Option<Message>,
        value: LiquidityTypes,
        active: bool,
        tooltip: impl ToString,
        price_range: impl ToString,
    ) -> Column<'a, Message>
    where
        Message: 'a + Clone + Default,
    {
        let mut value = label(value.to_string()).secondary();
        let mut background = ExcaliburColor::Background3;

        if active {
            value = value.highlight();
            background = ExcaliburColor::Background4;
        }

        Column::new().push(
            ExcaliburButton::new()
                .selectable()
                .border_radius(8.0.into())
                .active()
                .background(background)
                .build(
                    Column::new()
                        .push(
                            Row::new()
                                .padding(Sizes::Md)
                                .spacing(Sizes::Sm)
                                .width(Length::Fill)
                                .align_items(alignment::Alignment::Center)
                                .push(Column::new().push(label("Type").build()))
                                .push(
                                    Column::new()
                                        .width(Length::FillPortion(3))
                                        .align_items(alignment::Alignment::End)
                                        .push(value),
                                ),
                        )
                        .push(
                            ExcaliburContainer::default()
                                .light_border()
                                .border_radius([0.0, 0.0, 8.0, 8.0].into())
                                .build(
                                    Row::new()
                                        .padding(Padding {
                                            top: Sizes::Sm.into(),
                                            bottom: Sizes::Sm.into(),
                                            left: Sizes::Md.into(),
                                            right: Sizes::Md.into(),
                                        })
                                        .width(Length::Fill)
                                        .push(
                                            ExcaliburTooltip::new()
                                                .caption()
                                                .secondary()
                                                .padding(Sizes::Sm)
                                                .info()
                                                .build(tooltip),
                                        )
                                        .push(
                                            Row::new().width(Length::Fill).push(
                                                Column::new()
                                                    .push(
                                                        Row::new()
                                                            .push(
                                                                label("Price Range: ")
                                                                    .secondary()
                                                                    .caption()
                                                                    .build(),
                                                            )
                                                            .push(
                                                                label(price_range)
                                                                    .secondary()
                                                                    .caption()
                                                                    .build(),
                                                            ),
                                                    )
                                                    .width(Length::Fill)
                                                    .align_items(alignment::Alignment::End),
                                            ),
                                        ),
                                )
                                .width(Length::Fill),
                        ),
                )
                .padding(0)
                .width(Length::Fill)
                .on_press_maybe(on_press),
        )
    }

    /// Form submit button for creating the position.
    pub fn submit<'a, Message>(
        on_submit: Option<Message>,
        state: &SubmitState,
    ) -> Container<'a, Message>
    where
        Message: 'a + Clone,
    {
        let mut on_submit = on_submit;
        let mut button_content = Row::new()
            .spacing(Sizes::Sm)
            .align_items(alignment::Alignment::Center);

        let loading_indicator = iced_loading_indicator::Widget::new(
            LOADING_INDICATOR_SIZE,
            Some(iced_loading_indicator::Style::CustomColor(
                iced::Color::from_rgb8(0xaa, 0xaa, 0xff),
            )),
            true,
        )
        .tick_duration_ms(LOADING_INDICATOR_SPEED_MS);

        match *state {
            SubmitState::Empty => {
                let mut cta = label("Submit Transaction");
                if on_submit.is_none() {
                    cta = cta.secondary();
                }

                let mut icon = label(icon_to_char(Icon::ShieldShaded)).icon();
                if on_submit.is_none() {
                    icon = icon.secondary();
                }

                button_content = button_content.push(icon.build()).push(cta.build());
            }
            SubmitState::Pending => {
                button_content = button_content
                    .push(loading_indicator)
                    .push(label("Transaction pending...").secondary().build());
                on_submit = None;
            }
            SubmitState::Confirmed => {
                button_content = button_content
                    .push(label(icon_to_char(Icon::CheckAll)).icon().title2().build())
                    .push(label("Success - continue").build());
            }
            SubmitState::Failed => {
                button_content = button_content
                    .push(label(icon_to_char(Icon::X)).icon().build())
                    .push(label("Failed").build());
            }
        }

        ExcaliburContainer::default().transparent().build(
            Column::new()
                .spacing(Sizes::Md)
                .push(label("Submit").secondary().build())
                .push(
                    ExcaliburButton::new()
                        .primary()
                        .build(button_content)
                        .padding(Padding {
                            top: Sizes::Md.into(),
                            bottom: Sizes::Md.into(),
                            left: Sizes::Lg.into(),
                            right: Sizes::Lg.into(),
                        })
                        .on_press_maybe(on_submit),
                )
                .width(Length::Fill),
        )
    }

    /// Form input for the deposit amount.
    pub fn deposit_input<'a, Message>(
        deposit_amount: Option<String>,
        on_change_deposit: impl Fn(Option<String>) -> Message + 'a,
    ) -> Container<'a, Message>
    where
        Message: 'a + Default + Clone,
    {
        Self::form_item(
            "Deposit",
            Column::new()
                .push(
                    ExcaliburInputBuilder::new()
                        .light_border()
                        .border_radius([8.0, 8.0, 0.0, 0.0].into())
                        .placeholder("Enter deposit amount".to_string())
                        .width(Length::Fill)
                        .padding(Padding {
                            top: Sizes::Lg.into(),
                            bottom: Sizes::Lg.into(),
                            left: Sizes::Md.into(),
                            right: Sizes::Md.into(),
                        })
                        .size(system::Typography::Headline)
                        .icon(iced::widget::text_input::Icon::<iced::Font> {
                            font: ICON_FONT,
                            code_point: icon_to_char(iced_aw::Icon::ShieldShaded),
                            size: Some(Sizes::Md.into()),
                            spacing: Sizes::Sm.into(),
                            side: iced::widget::text_input::Side::Left,
                        })
                        .build(deposit_amount, on_change_deposit),
                )
                .push(
                    ExcaliburContainer::default()
                        .light_border()
                        .border_radius([0.0, 0.0, 8.0, 8.0].into())
                        .build(
                            Row::new()
                                .padding(Padding {
                                    top: Sizes::Sm.into(),
                                    bottom: Sizes::Sm.into(),
                                    left: Sizes::Md.into(),
                                    right: Sizes::Md.into(),
                                })
                                .push(label("Max").caption().secondary().build()),
                        )
                        .width(Length::Fill),
                ),
        )
    }

    #[allow(dead_code)]
    pub fn duration_form<'a, Message>(
        choice_duration: Vec<Times>,
        chosen_duration: Option<Times>,
        on_select_duration: impl Fn(Times) -> Message + 'a,
    ) -> Container<'a, Message>
    where
        Message: 'a + Default,
    {
        Self::form_item(
            "Duration",
            Column::new().push(
                excalibur_select(
                    choice_duration,
                    chosen_duration,
                    on_select_duration,
                    "Select duration",
                    Some(8.0.into()),
                )
                .padding(Sizes::Md)
                .width(Length::Fill),
            ),
        )
    }

    #[allow(dead_code)]
    pub fn liquidity_type_form<'a, Message>(
        choice_liquidity: Vec<LiquidityTypes>,
        chosen_liquidity: Option<LiquidityTypes>,
        on_select_liquidity: impl Fn(LiquidityTypes) -> Message + 'a,
    ) -> Container<'a, Message>
    where
        Message: 'a + Default,
    {
        Self::form_item(
            "Liquidity Type",
            Column::new()
                .push(
                    excalibur_select(
                        choice_liquidity,
                        chosen_liquidity,
                        on_select_liquidity,
                        "Select liquidity type",
                        Some([8.0, 8.0, 0.0, 0.0].into()),
                    )
                    .padding(Sizes::Md)
                    .width(Length::Fill),
                )
                .push(
                    ExcaliburContainer::default()
                        .light_border()
                        .border_radius([0.0, 0.0, 8.0, 8.0].into())
                        .build(
                            Row::new()
                                .padding(Sizes::Sm)
                                .push(
                                    label(icon_to_char(iced_aw::Icon::Info))
                                        .icon()
                                        .secondary()
                                        .caption()
                                        .build(),
                                )
                                .push(label("Range: ").caption().secondary().build()),
                        )
                        .width(Length::Fill),
                ),
        )
    }

    #[allow(dead_code)]
    pub fn target_price_form<'a, Message>(
        target_price: Option<String>,
        on_change_end_price: impl Fn(Option<String>) -> Message + 'a,
    ) -> Container<'a, Message>
    where
        Message: 'a + Default + Clone,
    {
        Self::form_item(
            "Target Price",
            Column::new().push(
                ExcaliburInputBuilder::new()
                    .light_border()
                    .border_radius([8.0, 8.0, 0.0, 0.0].into())
                    .placeholder("Enter target price".to_string())
                    .width(Length::Fill)
                    .padding(Sizes::Md.into())
                    .icon(iced::widget::text_input::Icon::<iced::Font> {
                        font: ICON_FONT,
                        code_point: icon_to_char(iced_aw::Icon::Check),
                        size: Some(Sizes::Md.into()),
                        spacing: Sizes::Sm.into(),
                        side: iced::widget::text_input::Side::Left,
                    })
                    .build(target_price, on_change_end_price),
            ),
        )
    }

    /// "Cast" of a single form element.
    pub fn form_item<'a, Message>(
        title: impl ToString,
        content: impl Into<Element<'a, Message>>,
    ) -> Container<'a, Message>
    where
        Message: 'a + Default,
    {
        ExcaliburContainer::default().transparent().build(
            Column::new()
                .spacing(Sizes::Md)
                .push(label(title).secondary().build())
                .push(
                    ExcaliburContainer::default()
                        .round(Sizes::Sm)
                        .middle_top()
                        .light_border()
                        .build(content),
                ),
        )
    }

    /// Layout of the chart.
    pub fn chart_layout<'a, Message>(
        chart: &'a ExcaliburChart,
        chart_title: ExcaliburText,
        sync_timestamp: ExcaliburText,
    ) -> Column<'a, Message>
    where
        Message: 'a + Default,
    {
        Column::new()
            .spacing(Sizes::Md)
            .push(
                Row::new()
                    .align_items(alignment::Alignment::Center)
                    .spacing(Sizes::Md)
                    .push(chart_title.build())
                    .push(sync_timestamp.build()),
            )
            .push(
                ExcaliburContainer::default()
                    .build(chart.build().map(|_| Message::default()))
                    .width(Length::Fill)
                    .height(350.0),
            )
    }

    /// Layout of the chart.
    pub fn chart_layout_histogram<'a, Message>(
        chart: &'a ExcaliburHistogram,
        chart_title: ExcaliburText,
        sync_timestamp: ExcaliburText,
    ) -> Column<'a, Message>
    where
        Message: 'a + Default,
    {
        Column::new()
            .spacing(Sizes::Md)
            .push(
                Row::new()
                    .align_items(alignment::Alignment::Center)
                    .spacing(Sizes::Md)
                    .push(chart_title.build())
                    .push(sync_timestamp.build()),
            )
            .push(
                ExcaliburContainer::default()
                    .build(chart.build().map(|_| Message::default()))
                    .width(Length::Fill)
                    .height(350.0),
            )
    }
}

const LOADING_INDICATOR_SIZE: f32 = 16.0;
const LOADING_INDICATOR_SPEED_MS: u64 = 85;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LiquidityChoices {
    pub liquidity_type: LiquidityTypes,
    pub last_price: f64,
    pub price_range: (f64, f64),
}

pub trait EnumList<T> {
    fn to_options() -> Vec<Self>
    where
        Self: Sized;
    fn to_list() -> Vec<String>;
    fn to_value(&self) -> T;
}

#[derive(Debug, Clone, Copy, Eq, PartialEq)]
pub enum Times {
    Now,
    OneHour,
    TwelveHour,
    OneDay,
    OneWeek,
    TwoWeeks,
    OneMonth,
}

impl Times {
    pub fn to_seconds(self) -> f64 {
        self.to_value()
    }
}

impl Display for Times {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Times::Now => write!(f, "Now"),
            Times::OneHour => write!(f, "1 hour"),
            Times::TwelveHour => write!(f, "12 hours"),
            Times::OneDay => write!(f, "1 day"),
            Times::OneWeek => write!(f, "1 week"),
            Times::TwoWeeks => write!(f, "2 weeks"),
            Times::OneMonth => write!(f, "1 month"),
        }
    }
}

impl EnumList<f64> for Times {
    fn to_options() -> Vec<Times> {
        vec![
            Times::Now,
            Times::OneHour,
            Times::TwelveHour,
            Times::OneDay,
            Times::OneWeek,
            Times::TwoWeeks,
            Times::OneMonth,
        ]
    }

    fn to_list() -> Vec<String> {
        vec![
            Times::Now.to_string(),
            Times::OneHour.to_string(),
            Times::TwelveHour.to_string(),
            Times::OneDay.to_string(),
            Times::OneWeek.to_string(),
            Times::TwoWeeks.to_string(),
            Times::OneMonth.to_string(),
        ]
    }

    fn to_value(&self) -> f64 {
        match self {
            Times::Now => 0.0,
            Times::OneHour => chrono::Duration::hours(1).num_seconds() as f64,

            Times::TwelveHour => chrono::Duration::hours(12).num_seconds() as f64,
            Times::OneDay => chrono::Duration::days(1).num_seconds() as f64,

            Times::OneWeek => chrono::Duration::weeks(1).num_seconds() as f64,
            Times::TwoWeeks => chrono::Duration::weeks(2).num_seconds() as f64,
            Times::OneMonth => chrono::Duration::weeks(4).num_seconds() as f64, // Approximation
        }
    }
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Default)]
#[allow(clippy::enum_variant_names)]
pub enum Fees {
    #[default]
    OneBps,
    ThreeBps,
    TenBps,
    ThirtyBps,
    FiftyBps,
    OneHundredBps,
}

impl Display for Fees {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Fees::OneBps => write!(f, "0.01%"),
            Fees::ThreeBps => write!(f, "0.03%"),
            Fees::TenBps => write!(f, "0.10%"),
            Fees::ThirtyBps => write!(f, "0.30%"),
            Fees::FiftyBps => write!(f, "0.50%"),
            Fees::OneHundredBps => write!(f, "1.00%"),
        }
    }
}

impl EnumList<f64> for Fees {
    fn to_options() -> Vec<Fees> {
        vec![
            Fees::OneBps,
            Fees::ThreeBps,
            Fees::TenBps,
            Fees::ThirtyBps,
            Fees::FiftyBps,
            Fees::OneHundredBps,
        ]
    }

    fn to_list() -> Vec<String> {
        vec![
            Fees::OneBps.to_string(),
            Fees::ThreeBps.to_string(),
            Fees::TenBps.to_string(),
            Fees::ThirtyBps.to_string(),
            Fees::FiftyBps.to_string(),
            Fees::OneHundredBps.to_string(),
        ]
    }

    fn to_value(&self) -> f64 {
        match self {
            Fees::OneBps => 0.0001,
            Fees::ThreeBps => 0.0003,
            Fees::TenBps => 0.001,
            Fees::ThirtyBps => 0.003,
            Fees::FiftyBps => 0.005,
            Fees::OneHundredBps => 0.01,
        }
    }
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Default)]
pub enum Strategies {
    #[default]
    Linear,
    SCurve,
    Exponential,
}

#[allow(dead_code)]
impl Strategies {
    pub fn description(&self) -> String {
        match self {
            Strategies::Linear => {
                "Changes the portfolio weights by the same amounts over time.".to_string()
            }
            Strategies::SCurve => {
                "Changes the portfolio weights slowly at first, then quickly, then slowly again."
                    .to_string()
            }
            Strategies::Exponential => {
                "Accelerates the portfolio weight changes until completion.".to_string()
            }
        }
    }
}

impl Display for Strategies {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Strategies::Linear => write!(f, "Linear"),
            Strategies::SCurve => write!(f, "S-Curve"),
            Strategies::Exponential => write!(f, "Exponential"),
        }
    }
}

impl EnumList<Strategies> for Strategies {
    fn to_options() -> Vec<Strategies> {
        vec![
            Strategies::Linear,
            Strategies::SCurve,
            Strategies::Exponential,
        ]
    }

    fn to_list() -> Vec<String> {
        vec![
            Strategies::Linear.to_string(),
            Strategies::SCurve.to_string(),
            Strategies::Exponential.to_string(),
        ]
    }

    fn to_value(&self) -> Strategies {
        *self
    }
}
